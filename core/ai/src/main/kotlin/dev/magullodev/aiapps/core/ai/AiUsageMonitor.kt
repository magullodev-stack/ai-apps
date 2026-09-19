package dev.magullodev.aiapps.core.ai

import java.math.BigDecimal
import java.math.RoundingMode
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
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.longOrNull
import kotlinx.serialization.json.put

interface AiUsageMonitor {
    fun recordCall(event: AiUsageCallEvent)

    fun recordMetric(event: AiUsageMetricEvent)

    companion object {
        val NOOP: AiUsageMonitor = object : AiUsageMonitor {
            override fun recordCall(event: AiUsageCallEvent) = Unit

            override fun recordMetric(event: AiUsageMetricEvent) = Unit
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
        private const val UNKNOWN_APPLICATION = "unknown-app"
    }
}

data class AiUsageFilter(
    val application: String? = null,
    val model: String? = null,
    val operation: String? = null,
    val workUnitId: String? = null,
)

class AiUsageRecordRepository(
    private val usageFile: Path,
) {
    private val json = Json { ignoreUnknownKeys = true }

    fun readAll(): List<AiUsageRecord> {
        if (!Files.exists(usageFile)) return emptyList()

        return Files.readAllLines(usageFile, StandardCharsets.UTF_8)
            .asSequence()
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .mapNotNull { line ->
                try {
                    parseRecord(json, line)
                } catch (_: Exception) {
                    null
                }
            }
            .toList()
    }
}

enum class AiCostDeterminability {
    KNOWN,
    PARTIAL,
    NOT_DETERMINABLE,
}

data class AiUsageCostEstimate(
    val determinability: AiCostDeterminability,
    val currency: String?,
    val amount: BigDecimal?,
)

data class AiUsageSummary(
    val calls: List<AiUsageRecord>,
    val metrics: List<AiUsageRecord>,
    val successfulCalls: Int,
    val failedCalls: Int,
    val totalKnownInputTokens: Long,
    val totalKnownOutputTokens: Long,
    val durationMillisByCallId: Map<String, Long>,
    val totalCostByCurrency: Map<String, BigDecimal>,
    val hasPartialOrUndeterminedCost: Boolean,
    val byApplication: Map<String, AiUsageGroupSummary>,
    val byModel: Map<String, AiUsageGroupSummary>,
    val byOperation: Map<String, AiUsageGroupSummary>,
)

data class AiUsageGroupSummary(
    val calls: Int,
    val failedCalls: Int,
    val totalKnownInputTokens: Long,
    val totalKnownOutputTokens: Long,
    val totalCostByCurrency: Map<String, BigDecimal>,
    val hasPartialOrUndeterminedCost: Boolean,
)

class AiUsageQueryService(
    private val repository: AiUsageRecordRepository,
) {
    fun summarize(filter: AiUsageFilter = AiUsageFilter()): AiUsageSummary {
        val all = repository.readAll()
        val filtered = all.filter { record ->
            match(filter.application, record.application) &&
                match(filter.model, record.model) &&
                match(filter.operation, record.operation) &&
                match(filter.workUnitId, record.workUnitId)
        }

        val calls = filtered.filter { it.type == "ai_call" }
        val metrics = filtered.filter { it.type == "metric" }

        val successfulCalls = calls.count { it.result == "success" }
        val failedCalls = calls.size - successfulCalls

        val inputTokens = calls.mapNotNull { it.inputTokens }.sum()
        val outputTokens = calls.mapNotNull { it.outputTokens }.sum()

        val perCallDurations = calls.associate { it.recordId to (it.durationMillis ?: 0L) }

        val costEstimates = calls.map { estimateCallCost(it) }
        val costByCurrency = costEstimates.mapNotNull { estimate ->
            val currency = estimate.currency ?: return@mapNotNull null
            val amount = estimate.amount ?: return@mapNotNull null
            currency to amount
        }.groupBy({ it.first }, { it.second }).mapValues { (_, values) -> values.fold(BigDecimal.ZERO) { acc, v -> acc + v } }

        val hasPartialOrUndetermined = costEstimates.any { it.determinability != AiCostDeterminability.KNOWN }

        return AiUsageSummary(
            calls = calls,
            metrics = metrics,
            successfulCalls = successfulCalls,
            failedCalls = failedCalls,
            totalKnownInputTokens = inputTokens,
            totalKnownOutputTokens = outputTokens,
            durationMillisByCallId = perCallDurations,
            totalCostByCurrency = costByCurrency,
            hasPartialOrUndeterminedCost = hasPartialOrUndetermined,
            byApplication = summarizeBy(calls) { it.application },
            byModel = summarizeBy(calls) { it.model ?: "unknown-model" },
            byOperation = summarizeBy(calls) { it.operation ?: "unknown-operation" },
        )
    }

    private fun summarizeBy(
        calls: List<AiUsageRecord>,
        keySelector: (AiUsageRecord) -> String,
    ): Map<String, AiUsageGroupSummary> = calls.groupBy(keySelector).toSortedMap().mapValues { (_, group) ->
        val estimates = group.map(::estimateCallCost)
        AiUsageGroupSummary(
            calls = group.size,
            failedCalls = group.count { it.result == "error" },
            totalKnownInputTokens = group.mapNotNull { it.inputTokens }.sum(),
            totalKnownOutputTokens = group.mapNotNull { it.outputTokens }.sum(),
            totalCostByCurrency = estimates.mapNotNull { estimate ->
                val currency = estimate.currency ?: return@mapNotNull null
                val amount = estimate.amount ?: return@mapNotNull null
                currency to amount
            }.groupBy({ it.first }, { it.second }).mapValues { (_, values) -> values.fold(BigDecimal.ZERO) { acc, value -> acc + value } },
            hasPartialOrUndeterminedCost = estimates.any { it.determinability != AiCostDeterminability.KNOWN },
        )
    }

    private fun match(expected: String?, actual: String?): Boolean {
        if (expected == null) return true
        return expected == actual
    }
}

fun estimateCallCost(record: AiUsageRecord): AiUsageCostEstimate {
    val rate = record.rate ?: return AiUsageCostEstimate(AiCostDeterminability.NOT_DETERMINABLE, null, null)

    val inputRate = rate.inputCostPerMillion.toBigDecimalOrNull() ?: return AiUsageCostEstimate(AiCostDeterminability.NOT_DETERMINABLE, rate.currency, null)
    val outputRate = rate.outputCostPerMillion.toBigDecimalOrNull() ?: return AiUsageCostEstimate(AiCostDeterminability.NOT_DETERMINABLE, rate.currency, null)

    val inputCost = record.inputTokens?.let { tokens ->
        inputRate.multiply(BigDecimal(tokens)).divide(ONE_MILLION, 12, RoundingMode.HALF_UP)
    }
    val outputCost = record.outputTokens?.let { tokens ->
        outputRate.multiply(BigDecimal(tokens)).divide(ONE_MILLION, 12, RoundingMode.HALF_UP)
    }

    return when {
        inputCost != null && outputCost != null -> AiUsageCostEstimate(
            determinability = AiCostDeterminability.KNOWN,
            currency = rate.currency,
            amount = inputCost + outputCost,
        )

        inputCost != null || outputCost != null -> AiUsageCostEstimate(
            determinability = AiCostDeterminability.PARTIAL,
            currency = rate.currency,
            amount = (inputCost ?: BigDecimal.ZERO) + (outputCost ?: BigDecimal.ZERO),
        )

        else -> AiUsageCostEstimate(
            determinability = AiCostDeterminability.NOT_DETERMINABLE,
            currency = rate.currency,
            amount = null,
        )
    }
}

fun formatUsageSummary(summary: AiUsageSummary): String {
    if (summary.calls.isEmpty() && summary.metrics.isEmpty()) {
        return "AI usage monitor\nNo records found."
    }

    val allTimes = (summary.calls + summary.metrics).mapNotNull { runCatching { Instant.parse(it.timestamp) }.getOrNull() }
    val from = allTimes.minOrNull()
    val to = allTimes.maxOrNull()

    return buildString {
        appendLine("AI usage monitor")
        appendLine("Period: ${from ?: "unknown"} -> ${to ?: "unknown"}")
        appendLine("Calls: ${summary.calls.size} (success=${summary.successfulCalls}, failed=${summary.failedCalls})")
        appendLine("Known tokens: input=${summary.totalKnownInputTokens}, output=${summary.totalKnownOutputTokens}")

        if (summary.totalCostByCurrency.isEmpty()) {
            appendLine("Estimated total cost: not determinable")
        } else {
            val costs = summary.totalCostByCurrency.entries.joinToString(", ") { (currency, amount) ->
                "${amount.setScale(6, RoundingMode.HALF_UP).toPlainString()} $currency"
            }
            appendLine("Estimated total cost: $costs")
        }
        if (summary.hasPartialOrUndeterminedCost) {
            appendLine("WARNING: cost includes partial or undetermined records")
        }

        appendLine("By application:")
        summary.byApplication.forEach { (application, group) ->
            appendLine("- $application: calls=${group.calls}, failed=${group.failedCalls}, input=${group.totalKnownInputTokens}, output=${group.totalKnownOutputTokens}, cost=${formatCosts(group.totalCostByCurrency, group.hasPartialOrUndeterminedCost)}")
        }

        appendLine("By model:")
        summary.byModel.forEach { (model, group) ->
            appendLine("- $model: calls=${group.calls}, failed=${group.failedCalls}, input=${group.totalKnownInputTokens}, output=${group.totalKnownOutputTokens}, cost=${formatCosts(group.totalCostByCurrency, group.hasPartialOrUndeterminedCost)}")
        }

        appendLine("By operation:")
        summary.byOperation.forEach { (operation, group) ->
            appendLine("- $operation: calls=${group.calls}, failed=${group.failedCalls}, input=${group.totalKnownInputTokens}, output=${group.totalKnownOutputTokens}, cost=${formatCosts(group.totalCostByCurrency, group.hasPartialOrUndeterminedCost)}")
        }

        val metricByName = summary.metrics.groupBy { it.metricName ?: "unknown-metric" }
        appendLine("Metric events:")
        metricByName.toSortedMap().forEach { (metricName, records) ->
            appendLine("- $metricName: events=${records.size}")
            records.sortedBy { it.timestamp }.forEach { record ->
                val values = if (record.metricValues.isEmpty()) {
                    "none"
                } else {
                    record.metricValues.toSortedMap().entries.joinToString(", ") { (name, value) -> "$name=$value" }
                }
                appendLine("  event workUnit=${record.workUnitId ?: "-"}, values=$values")
            }
        }
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

private fun formatCosts(costByCurrency: Map<String, BigDecimal>, partial: Boolean): String {
    val known = if (costByCurrency.isEmpty()) {
        "not determinable"
    } else {
        costByCurrency.entries.joinToString(", ") { (currency, amount) ->
            "${amount.setScale(6, RoundingMode.HALF_UP).toPlainString()} $currency"
        }
    }

    return if (partial) "$known (partial)" else known
}

private val ONE_MILLION = BigDecimal("1000000")

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
}

private fun parseRecord(json: Json, line: String): AiUsageRecord? {
    val obj = json.parseToJsonElement(line) as? JsonObject ?: return null

    val recordId = (obj["recordId"] as? JsonPrimitive)?.content?.takeIf { it.isNotBlank() } ?: return null
    val timestamp = (obj["timestamp"] as? JsonPrimitive)?.content?.takeIf { it.isNotBlank() } ?: return null
    val type = (obj["type"] as? JsonPrimitive)?.content?.takeIf { it.isNotBlank() } ?: return null
    val application = (obj["application"] as? JsonPrimitive)?.content?.takeIf { it.isNotBlank() } ?: return null

    val rateObj = obj["rate"] as? JsonObject
    val rate = rateObj?.let {
        val currency = (it["currency"] as? JsonPrimitive)?.content ?: return@let null
        val inputCost = (it["inputCostPerMillion"] as? JsonPrimitive)?.content ?: return@let null
        val outputCost = (it["outputCostPerMillion"] as? JsonPrimitive)?.content ?: return@let null
        AiUsageRateSnapshot(currency = currency, inputCostPerMillion = inputCost, outputCostPerMillion = outputCost)
    }

    val metricValues = (obj["metricValues"] as? JsonObject)
        ?.mapNotNull { (key, value) ->
            val asLong = (value as? JsonPrimitive)?.longOrNull ?: return@mapNotNull null
            key to asLong
        }
        ?.toMap()
        ?: emptyMap()

    return AiUsageRecord(
        recordId = recordId,
        timestamp = timestamp,
        type = type,
        application = application,
        workUnitId = (obj["workUnitId"] as? JsonPrimitive)?.content,
        operation = (obj["operation"] as? JsonPrimitive)?.content,
        model = (obj["model"] as? JsonPrimitive)?.content,
        durationMillis = (obj["durationMillis"] as? JsonPrimitive)?.longOrNull,
        result = (obj["result"] as? JsonPrimitive)?.content,
        inputTokens = (obj["inputTokens"] as? JsonPrimitive)?.longOrNull,
        outputTokens = (obj["outputTokens"] as? JsonPrimitive)?.longOrNull,
        totalTokens = (obj["totalTokens"] as? JsonPrimitive)?.longOrNull,
        usageKnown = (obj["usageKnown"] as? JsonPrimitive)?.booleanOrNull,
        errorCode = (obj["errorCode"] as? JsonPrimitive)?.content,
        rate = rate,
        metricName = (obj["metricName"] as? JsonPrimitive)?.content,
        metricValues = metricValues,
    )
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
