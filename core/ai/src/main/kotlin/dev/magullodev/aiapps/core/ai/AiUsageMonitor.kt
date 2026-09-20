package dev.magullodev.aiapps.core.ai

import java.math.BigDecimal
import java.nio.ByteBuffer
import java.nio.channels.FileChannel
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardOpenOption
import java.time.Clock
import java.time.Instant
import java.util.UUID
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

interface AiUsageMonitor {
    fun recordCall(event: AiUsageCallEvent)

    fun recordMetric(event: AiUsageMetricEvent)

    fun recordAudit(event: AiUsageAuditEvent)

    companion object {
        val NOOP: AiUsageMonitor = object : AiUsageMonitor {
            override fun recordCall(event: AiUsageCallEvent) = Unit

            override fun recordMetric(event: AiUsageMetricEvent) = Unit

            override fun recordAudit(event: AiUsageAuditEvent) = Unit
        }
    }
}

enum class AiUsageOperation {
    COVERAGE,
    REVIEW,
    SUBSTITUTIONS,
    LUNA,
    OTHER,
}

enum class AiUsageCallResult {
    SUCCESS,
    ERROR,
}

data class AiUsageCallEvent(
    val application: String,
    val operation: AiUsageOperation,
    val model: String,
    val durationMillis: Long,
    val result: AiUsageCallResult,
    val workUnitId: String? = null,
    val inputTokens: Long? = null,
    val outputTokens: Long? = null,
    val totalTokens: Long? = null,
    val usageKnown: Boolean,
    val errorCode: String? = null,
)

data class AiUsageMetricEvent(
    val application: String,
    val metricName: String,
    val values: Map<String, Long>,
    val workUnitId: String? = null,
)

enum class AiUsageAuditResult {
    ACCEPTED,
    REJECTED,
}

data class AiUsageAuditEvent(
    val application: String,
    val audit: String,
    val phase: String,
    val result: AiUsageAuditResult,
    val workUnitId: String? = null,
    val position: Int? = null,
    val attempt: Int? = null,
    val reason: String? = null,
)

data class AiUsageRateSnapshot(
    val currency: String,
    val inputCostPerMillion: String,
    val outputCostPerMillion: String,
)

data class AiUsageRecord(
    val recordId: String,
    val timestamp: String,
    val type: String,
    val application: String,
    val workUnitId: String? = null,
    val operation: String? = null,
    val model: String? = null,
    val durationMillis: Long? = null,
    val result: String? = null,
    val inputTokens: Long? = null,
    val outputTokens: Long? = null,
    val totalTokens: Long? = null,
    val usageKnown: Boolean? = null,
    val errorCode: String? = null,
    val rate: AiUsageRateSnapshot? = null,
    val metricName: String? = null,
    val metricValues: Map<String, Long> = emptyMap(),
    val auditName: String? = null,
    val auditPhase: String? = null,
    val auditResult: String? = null,
    val auditPosition: Int? = null,
    val auditAttempt: Int? = null,
    val auditReason: String? = null,
)

data class ModelRate(
    val currency: String,
    val inputCostPerMillion: BigDecimal,
    val outputCostPerMillion: BigDecimal,
) {
    init {
        require(currency.isNotBlank()) { "Rate currency must not be blank" }
        require(inputCostPerMillion >= BigDecimal.ZERO) { "Input rate must be >= 0" }
        require(outputCostPerMillion >= BigDecimal.ZERO) { "Output rate must be >= 0" }
    }

    fun snapshot(): AiUsageRateSnapshot = AiUsageRateSnapshot(
        currency = currency,
        inputCostPerMillion = inputCostPerMillion.stripTrailingZeros().toPlainString(),
        outputCostPerMillion = outputCostPerMillion.stripTrailingZeros().toPlainString(),
    )
}

class FileAiUsageMonitor(
    private val usageFile: Path,
    private val ratesByModel: Map<String, ModelRate>,
    private val clock: Clock = Clock.systemUTC(),
) : AiUsageMonitor {
    private val json = Json { encodeDefaults = true; ignoreUnknownKeys = true }
    private val writeMutex = Any()

    override fun recordCall(event: AiUsageCallEvent) {
        val record = AiUsageRecord(
            recordId = UUID.randomUUID().toString(),
            timestamp = Instant.now(clock).toString(),
            type = TYPE_CALL,
            application = event.application.trim().ifEmpty { UNKNOWN_APPLICATION },
            workUnitId = event.workUnitId?.trim()?.ifEmpty { null },
            operation = event.operation.name.lowercase(),
            model = event.model,
            durationMillis = event.durationMillis.coerceAtLeast(0),
            result = event.result.name.lowercase(),
            inputTokens = event.inputTokens,
            outputTokens = event.outputTokens,
            totalTokens = event.totalTokens,
            usageKnown = event.usageKnown,
            errorCode = event.errorCode,
            rate = ratesByModel[event.model]?.snapshot(),
        )
        writeSafely(record)
    }

    override fun recordMetric(event: AiUsageMetricEvent) {
        val record = AiUsageRecord(
            recordId = UUID.randomUUID().toString(),
            timestamp = Instant.now(clock).toString(),
            type = TYPE_METRIC,
            application = event.application.trim().ifEmpty { UNKNOWN_APPLICATION },
            workUnitId = event.workUnitId?.trim()?.ifEmpty { null },
            metricName = event.metricName.trim(),
            metricValues = event.values,
        )
        writeSafely(record)
    }

    override fun recordAudit(event: AiUsageAuditEvent) {
        val record = AiUsageRecord(
            recordId = UUID.randomUUID().toString(),
            timestamp = Instant.now(clock).toString(),
            type = TYPE_AUDIT,
            application = event.application.trim().ifEmpty { UNKNOWN_APPLICATION },
            workUnitId = event.workUnitId?.trim()?.ifEmpty { null },
            auditName = event.audit.trim().ifEmpty { "unknown-audit" },
            auditPhase = event.phase.trim().ifEmpty { "unknown-phase" },
            auditResult = event.result.name.lowercase(),
            auditPosition = event.position?.takeIf { it > 0 },
            auditAttempt = event.attempt?.takeIf { it > 0 },
            auditReason = sanitizeAuditReason(event.reason),
        )
        writeSafely(record)
    }

    private fun writeSafely(record: AiUsageRecord) {
        try {
            val parent = usageFile.parent
            if (parent != null) {
                Files.createDirectories(parent)
            }

            synchronized(writeMutex) {
                FileChannel.open(
                    usageFile,
                    StandardOpenOption.CREATE,
                    StandardOpenOption.READ,
                    StandardOpenOption.WRITE,
                ).use { channel ->
                    channel.lock().use {
                        val line = record.toJsonLine(json)
                        channel.position(channel.size())
                        channel.write(ByteBuffer.wrap(line.toByteArray(StandardCharsets.UTF_8)))
                        channel.force(true)
                    }
                }
            }
        } catch (_: Exception) {
            // Recording failures are non-fatal by design.
        }
    }

    companion object {
        private const val TYPE_CALL = "ai_call"
        private const val TYPE_METRIC = "metric"
        private const val TYPE_AUDIT = "audit"
        private const val UNKNOWN_APPLICATION = "unknown-app"
    }
}

fun resolveUsageFile(env: Map<String, String> = System.getenv()): Path {
    val configured = env["AI_APPS_USAGE_FILE"]?.trim().orEmpty()
    if (configured.isNotEmpty()) return Path.of(configured)
    return Path.of(System.getProperty("user.dir"), ".ai-apps", "usage", "ai-usage.jsonl")
}

fun loadModelRates(env: Map<String, String> = System.getenv()): Map<String, ModelRate> {
    val pathText = env["AI_APPS_PRICING_FILE"]?.trim().orEmpty()
    if (pathText.isEmpty()) return emptyMap()

    val path = Path.of(pathText)
    if (!Files.exists(path)) return emptyMap()

    val root = try {
        Json.parseToJsonElement(Files.readString(path)) as? JsonObject
    } catch (_: Exception) {
        null
    } ?: return emptyMap()

    val defaultCurrency = (root["currency"] as? JsonPrimitive)?.content?.trim().orEmpty().ifEmpty { "USD" }
    val models = root["models"] as? JsonObject ?: return emptyMap()

    return models.mapNotNull { (model, node) ->
        val fields = node as? JsonObject ?: return@mapNotNull null
        val input = (fields["inputCostPerMillion"] as? JsonPrimitive)?.content?.trim().orEmpty()
        val output = (fields["outputCostPerMillion"] as? JsonPrimitive)?.content?.trim().orEmpty()
        val currency = (fields["currency"] as? JsonPrimitive)?.content?.trim().orEmpty().ifEmpty { defaultCurrency }

        val inputCost = input.toBigDecimalOrNull() ?: return@mapNotNull null
        val outputCost = output.toBigDecimalOrNull() ?: return@mapNotNull null

        model to ModelRate(
            currency = currency,
            inputCostPerMillion = inputCost,
            outputCostPerMillion = outputCost,
        )
    }.toMap()
}

private fun sanitizeAuditReason(reason: String?): String? {
    val raw = reason?.trim()?.takeIf { it.isNotEmpty() } ?: return null
    val collapsed = raw.replace(Regex("\\s+"), " ")
    val redacted = collapsed
        .replace(Regex("(?i)authorization"), "[redacted]")
        .replace(Regex("(?i)bearer"), "[redacted]")
        .replace(Regex("(?i)api[_-]?key"), "[redacted]")
    return redacted.take(180)
}

private fun AiUsageRecord.toJsonLine(json: Json): String = json.encodeToString(toJsonObject()) + "\n"

private fun AiUsageRecord.toJsonObject(): JsonObject = buildJsonObject {
    put("recordId", recordId)
    put("timestamp", timestamp)
    put("type", type)
    put("application", application)
    workUnitId?.let { put("workUnitId", it) }
    operation?.let { put("operation", it) }
    model?.let { put("model", it) }
    durationMillis?.let { put("durationMillis", it) }
    result?.let { put("result", it) }
    inputTokens?.let { put("inputTokens", it) }
    outputTokens?.let { put("outputTokens", it) }
    totalTokens?.let { put("totalTokens", it) }
    usageKnown?.let { put("usageKnown", it) }
    errorCode?.let { put("errorCode", it) }
    rate?.let {
        put(
            "rate",
            buildJsonObject {
                put("currency", it.currency)
                put("inputCostPerMillion", it.inputCostPerMillion)
                put("outputCostPerMillion", it.outputCostPerMillion)
            },
        )
    }
    metricName?.let { put("metricName", it) }
    if (metricValues.isNotEmpty()) {
        put(
            "metricValues",
            buildJsonObject {
                metricValues.forEach { (key, value) -> put(key, value) }
            },
        )
    }
    auditName?.let { put("auditName", it) }
    auditPhase?.let { put("auditPhase", it) }
    auditResult?.let { put("auditResult", it) }
    auditPosition?.let { put("auditPosition", it) }
    auditAttempt?.let { put("auditAttempt", it) }
    auditReason?.let { put("auditReason", it) }
}

data class AiUsageContext(
    val application: String,
    val workUnitId: String?,
)

object AiUsageContextHolder {
    @PublishedApi
    internal val local = ThreadLocal<AiUsageContext?>()

    fun current(): AiUsageContext? = local.get()

    inline fun <T> withContext(context: AiUsageContext, block: () -> T): T {
        val previous = local.get()
        local.set(context)
        return try {
            block()
        } finally {
            if (previous == null) {
                local.remove()
            } else {
                local.set(previous)
            }
        }
    }
}
