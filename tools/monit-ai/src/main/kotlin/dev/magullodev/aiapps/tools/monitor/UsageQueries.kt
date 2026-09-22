package dev.magullodev.aiapps.tools.monitor

import dev.magullodev.aiapps.ai.AiUsageRecord
import dev.magullodev.aiapps.ai.AiUsageRateSnapshot
import dev.magullodev.aiapps.ai.ModelRate
import dev.magullodev.aiapps.tools.monitor.quiz10.Quiz10History
import dev.magullodev.aiapps.tools.monitor.quiz10.buildQuiz10History
import java.math.BigDecimal
import java.math.RoundingMode
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.longOrNull

data class AiUsageFilter(
    val application: String? = null,
    val model: String? = null,
    val operation: String? = null,
    val workUnitId: String? = null,
)

class AiUsageRecordRepository(
    private val usageFiles: List<Path>,
) {
    constructor(usageFile: Path) : this(listOf(usageFile))

    private val json = Json { ignoreUnknownKeys = true }

    fun readAll(): List<AiUsageRecord> {
        return usageFiles.asSequence().filter(Files::exists)
            .flatMap { Files.readAllLines(it, StandardCharsets.UTF_8).asSequence() }
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .mapNotNull { line ->
                try {
                    parseRecord(json, line)
                } catch (_: Exception) {
                    null
                }
            }
            .distinctBy { it.recordId }
            .toList()
    }
}

enum class AiCostDeterminability {
    KNOWN,
    PARTIAL,
    NOT_DETERMINABLE,
}

enum class AiCostRateSource { SNAPSHOT, RETROSPECTIVE, UNKNOWN }

data class AiUsageCostEstimate(
    val determinability: AiCostDeterminability,
    val currency: String?,
    val amount: BigDecimal?,
    val rateSource: AiCostRateSource = AiCostRateSource.UNKNOWN,
    val missingRateModels: Set<String> = emptySet(),
)

data class AiUsageSummary(
    val calls: List<AiUsageRecord>,
    val metrics: List<AiUsageRecord>,
    val audits: List<AiUsageRecord>,
    val successfulCalls: Int,
    val failedCalls: Int,
    val totalKnownInputTokens: Long,
    val totalKnownOutputTokens: Long,
    val durationMillisByCallId: Map<String, Long>,
    val totalCostByCurrency: Map<String, BigDecimal>,
    val hasPartialOrUndeterminedCost: Boolean,
    val hasRetrospectiveRates: Boolean,
    val missingRateModels: Set<String>,
    val byApplication: Map<String, AiUsageGroupSummary>,
    val byModel: Map<String, AiUsageGroupSummary>,
    val byOperation: Map<String, AiUsageGroupSummary>,
    val byExecution: Map<AiUsageExecutionKey, AiUsageExecutionSummary>,
)

data class AiUsageGroupSummary(
    val calls: Int,
    val failedCalls: Int,
    val totalKnownInputTokens: Long,
    val totalKnownOutputTokens: Long,
    val totalCostByCurrency: Map<String, BigDecimal>,
    val hasPartialOrUndeterminedCost: Boolean,
    val hasRetrospectiveRates: Boolean,
    val missingRateModels: Set<String>,
)

data class AiUsageExecutionKey(val application: String, val workUnitId: String)

data class AiUsageExecutionSummary(
    val calls: Int,
    val metrics: Int,
    val audits: Int,
    val totalCostByCurrency: Map<String, BigDecimal>,
    val hasPartialOrUndeterminedCost: Boolean,
    val hasRetrospectiveRates: Boolean,
    val missingRateModels: Set<String>,
)


class AiUsageQueryService(
    private val repository: AiUsageRecordRepository,
    private val ratesByModel: Map<String, ModelRate> = emptyMap(),
) {
    fun quiz10History(
        window: Int = 50,
        hiddenWorkUnits: Set<String> = emptySet(),
    ): Quiz10History = buildQuiz10History(
        repository.readAll().filterNot {
            it.application == "quiz10-web" && it.workUnitId != null && it.workUnitId in hiddenWorkUnits
        },
        window,
        ratesByModel,
    )

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
        val audits = filtered.filter { it.type == "audit" }

        val successfulCalls = calls.count { it.result == "success" }
        val failedCalls = calls.size - successfulCalls

        val inputTokens = calls.mapNotNull { it.inputTokens }.sum()
        val outputTokens = calls.mapNotNull { it.outputTokens }.sum()

        val perCallDurations = calls.associate { it.recordId to (it.durationMillis ?: 0L) }

        val costEstimates = calls.map { estimateCallCost(it, ratesByModel) }
        val costByCurrency = costEstimates.mapNotNull { estimate ->
            val currency = estimate.currency ?: return@mapNotNull null
            val amount = estimate.amount ?: return@mapNotNull null
            currency to amount
        }.groupBy({ it.first }, { it.second }).mapValues { (_, values) -> values.fold(BigDecimal.ZERO) { acc, v -> acc + v } }

        val hasPartialOrUndetermined = costEstimates.any { it.determinability != AiCostDeterminability.KNOWN }

        return AiUsageSummary(
            calls = calls,
            metrics = metrics,
            audits = audits,
            successfulCalls = successfulCalls,
            failedCalls = failedCalls,
            totalKnownInputTokens = inputTokens,
            totalKnownOutputTokens = outputTokens,
            durationMillisByCallId = perCallDurations,
            totalCostByCurrency = costByCurrency,
            hasPartialOrUndeterminedCost = hasPartialOrUndetermined,
            hasRetrospectiveRates = costEstimates.any { it.rateSource == AiCostRateSource.RETROSPECTIVE },
            missingRateModels = costEstimates.flatMap { it.missingRateModels }.toSet(),
            byApplication = summarizeBy(calls) { it.application },
            byModel = summarizeBy(calls) { it.model ?: "unknown-model" },
            byOperation = summarizeBy(calls) { it.operation ?: "unknown-operation" },
            byExecution = filtered.groupBy { AiUsageExecutionKey(it.application, it.workUnitId ?: "-") }
                .toSortedMap(compareBy<AiUsageExecutionKey> { it.application }.thenBy { it.workUnitId })
                .mapValues { (_, records) ->
                    val group = records.filter { it.type == "ai_call" }
                    val costs = group.map { estimateCallCost(it, ratesByModel) }
                    AiUsageExecutionSummary(
                        calls = group.size,
                        metrics = records.count { it.type == "metric" },
                        audits = records.count { it.type == "audit" },
                        totalCostByCurrency = costs.mapNotNull { cost ->
                            val currency = cost.currency ?: return@mapNotNull null
                            val amount = cost.amount ?: return@mapNotNull null
                            currency to amount
                        }.groupBy({ it.first }, { it.second }).mapValues { (_, values) -> values.fold(BigDecimal.ZERO, BigDecimal::add) },
                        hasPartialOrUndeterminedCost = costs.any { it.determinability != AiCostDeterminability.KNOWN },
                        hasRetrospectiveRates = costs.any { it.rateSource == AiCostRateSource.RETROSPECTIVE },
                        missingRateModels = costs.flatMap { it.missingRateModels }.toSet(),
                    )
                },
        )
    }

    private fun summarizeBy(
        calls: List<AiUsageRecord>,
        keySelector: (AiUsageRecord) -> String,
    ): Map<String, AiUsageGroupSummary> = calls.groupBy(keySelector).toSortedMap().mapValues { (_, group) ->
        val estimates = group.map { estimateCallCost(it, ratesByModel) }
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
            hasRetrospectiveRates = estimates.any { it.rateSource == AiCostRateSource.RETROSPECTIVE },
            missingRateModels = estimates.flatMap { it.missingRateModels }.toSet(),
        )
    }

    private fun match(expected: String?, actual: String?): Boolean {
        if (expected == null) return true
        return expected == actual
    }
}

data class AiUsageCallCosts(
    val input: AiUsageCostEstimate,
    val output: AiUsageCostEstimate,
    val total: AiUsageCostEstimate,
)

fun estimateCallCost(
    record: AiUsageRecord,
    ratesByModel: Map<String, ModelRate> = emptyMap(),
): AiUsageCostEstimate = estimateCallCosts(record, ratesByModel).total

fun estimateCallCosts(
    record: AiUsageRecord,
    ratesByModel: Map<String, ModelRate> = emptyMap(),
): AiUsageCallCosts {
    val model = record.model ?: "unknown-model"
    val rate = record.rate ?: ratesByModel[model]?.snapshot()
    val source = when {
        record.rate != null -> AiCostRateSource.SNAPSHOT
        rate != null -> AiCostRateSource.RETROSPECTIVE
        else -> AiCostRateSource.UNKNOWN
    }
    if (rate == null) {
        val unknown = AiUsageCostEstimate(AiCostDeterminability.NOT_DETERMINABLE, null, null,
            missingRateModels = setOf(model))
        return AiUsageCallCosts(unknown, unknown, unknown)
    }
    val inputRate = rate.inputCostPerMillion.toBigDecimalOrNull()
    val outputRate = rate.outputCostPerMillion.toBigDecimalOrNull()
    if (inputRate == null || outputRate == null) {
        val unknown = AiUsageCostEstimate(AiCostDeterminability.NOT_DETERMINABLE, rate.currency, null,
            source, setOf(model))
        return AiUsageCallCosts(unknown, unknown, unknown)
    }
    fun component(tokens: Long?, price: BigDecimal): AiUsageCostEstimate = if (tokens == null)
        AiUsageCostEstimate(AiCostDeterminability.NOT_DETERMINABLE, rate.currency, null, source)
    else AiUsageCostEstimate(AiCostDeterminability.KNOWN, rate.currency,
        price.multiply(BigDecimal(tokens)).divide(ONE_MILLION, 12, RoundingMode.HALF_UP), source)

    val input = component(record.inputTokens, inputRate)
    val output = component(record.outputTokens, outputRate)
    val total = when {
        input.amount != null && output.amount != null -> AiUsageCostEstimate(
            AiCostDeterminability.KNOWN, rate.currency, input.amount + output.amount, source)
        input.amount != null || output.amount != null -> AiUsageCostEstimate(
            AiCostDeterminability.PARTIAL, rate.currency,
            (input.amount ?: BigDecimal.ZERO) + (output.amount ?: BigDecimal.ZERO), source)
        else -> AiUsageCostEstimate(AiCostDeterminability.NOT_DETERMINABLE, rate.currency, null, source)
    }
    return AiUsageCallCosts(input, output, total)
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

private val ONE_MILLION = BigDecimal("1000000")

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
        auditName = (obj["auditName"] as? JsonPrimitive)?.content,
        auditPhase = (obj["auditPhase"] as? JsonPrimitive)?.content,
        auditResult = (obj["auditResult"] as? JsonPrimitive)?.content,
        auditPosition = (obj["auditPosition"] as? JsonPrimitive)?.intOrNull,
        auditAttempt = (obj["auditAttempt"] as? JsonPrimitive)?.intOrNull,
        auditReason = sanitizeAuditReason((obj["auditReason"] as? JsonPrimitive)?.content),
    )
}
