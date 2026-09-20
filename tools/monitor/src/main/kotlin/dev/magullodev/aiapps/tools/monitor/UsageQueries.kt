package dev.magullodev.aiapps.tools.monitor

import dev.magullodev.aiapps.core.ai.AiUsageRecord
import dev.magullodev.aiapps.core.ai.AiUsageRateSnapshot
import dev.magullodev.aiapps.core.ai.ModelRate
import dev.magullodev.aiapps.tools.monitor.quiz10.Quiz10History
import dev.magullodev.aiapps.tools.monitor.quiz10.buildQuiz10History
import java.math.BigDecimal
import java.math.RoundingMode
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import java.time.Instant
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
    fun quiz10History(window: Int = 50): Quiz10History = buildQuiz10History(repository.readAll(), window, ratesByModel)

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

fun estimateCallCost(
    record: AiUsageRecord,
    ratesByModel: Map<String, ModelRate> = emptyMap(),
): AiUsageCostEstimate {
    val model = record.model ?: "unknown-model"
    val rate = record.rate ?: ratesByModel[model]?.snapshot()
        ?: return AiUsageCostEstimate(AiCostDeterminability.NOT_DETERMINABLE, null, null,
            missingRateModels = setOf(model))
    val source = if (record.rate != null) AiCostRateSource.SNAPSHOT else AiCostRateSource.RETROSPECTIVE
    val inputRate = rate.inputCostPerMillion.toBigDecimalOrNull()
        ?: return AiUsageCostEstimate(AiCostDeterminability.NOT_DETERMINABLE, rate.currency, null, source, setOf(model))
    val outputRate = rate.outputCostPerMillion.toBigDecimalOrNull()
        ?: return AiUsageCostEstimate(AiCostDeterminability.NOT_DETERMINABLE, rate.currency, null, source, setOf(model))

    val inputCost = record.inputTokens?.let { tokens ->
        inputRate.multiply(BigDecimal(tokens)).divide(ONE_MILLION, 12, RoundingMode.HALF_UP)
    }
    val outputCost = record.outputTokens?.let { tokens ->
        outputRate.multiply(BigDecimal(tokens)).divide(ONE_MILLION, 12, RoundingMode.HALF_UP)
    }
    return when {
        inputCost != null && outputCost != null -> AiUsageCostEstimate(
            AiCostDeterminability.KNOWN, rate.currency, inputCost + outputCost, source)
        inputCost != null || outputCost != null -> AiUsageCostEstimate(
            AiCostDeterminability.PARTIAL, rate.currency,
            (inputCost ?: BigDecimal.ZERO) + (outputCost ?: BigDecimal.ZERO), source)
        else -> AiUsageCostEstimate(AiCostDeterminability.NOT_DETERMINABLE, rate.currency, null, source)
    }
}

fun formatUsageSummary(summary: AiUsageSummary): String {
    if (summary.calls.isEmpty() && summary.metrics.isEmpty() && summary.audits.isEmpty()) {
        return "AI usage monitor\nNo records found."
    }

    val allTimes = (summary.calls + summary.metrics + summary.audits).mapNotNull { runCatching { Instant.parse(it.timestamp) }.getOrNull() }
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
        if (summary.hasRetrospectiveRates) appendLine("Rates: includes retrospective estimates from AI_APPS_PRICING_FILE")
        if (summary.missingRateModels.isNotEmpty()) appendLine("Missing rates for models: ${summary.missingRateModels.sorted().joinToString(", ")}; configure AI_APPS_PRICING_FILE")

        appendLine("By application:")
        summary.byApplication.forEach { (application, group) ->
            appendLine("- $application: calls=${group.calls}, failed=${group.failedCalls}, input=${group.totalKnownInputTokens}, output=${group.totalKnownOutputTokens}, cost=${formatCosts(group.totalCostByCurrency, group.hasPartialOrUndeterminedCost, group.hasRetrospectiveRates, group.missingRateModels)}")
        }

        appendLine("By model:")
        summary.byModel.forEach { (model, group) ->
            appendLine("- $model: calls=${group.calls}, failed=${group.failedCalls}, input=${group.totalKnownInputTokens}, output=${group.totalKnownOutputTokens}, cost=${formatCosts(group.totalCostByCurrency, group.hasPartialOrUndeterminedCost, group.hasRetrospectiveRates, group.missingRateModels)}")
        }

        appendLine("By operation:")
        summary.byOperation.forEach { (operation, group) ->
            appendLine("- $operation: calls=${group.calls}, failed=${group.failedCalls}, input=${group.totalKnownInputTokens}, output=${group.totalKnownOutputTokens}, cost=${formatCosts(group.totalCostByCurrency, group.hasPartialOrUndeterminedCost, group.hasRetrospectiveRates, group.missingRateModels)}")
        }

        appendLine("By execution:")
        summary.byExecution.forEach { (key, execution) ->
            appendLine("- app=${key.application} workUnit=${key.workUnitId}: calls=${execution.calls}, metrics=${execution.metrics}, audits=${execution.audits}, cost=${formatCosts(execution.totalCostByCurrency, execution.hasPartialOrUndeterminedCost, execution.hasRetrospectiveRates, execution.missingRateModels)}")
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

        appendLine("Audit events:")
        append(renderAuditSummary(summary))
    }
}

private fun formatCosts(
    costByCurrency: Map<String, BigDecimal>,
    partial: Boolean,
    retrospective: Boolean,
    missingRateModels: Set<String>,
): String {
    val known = if (costByCurrency.isEmpty()) "not determinable" else
        costByCurrency.entries.joinToString(", ") { (currency, amount) ->
            "${amount.setScale(6, RoundingMode.HALF_UP).toPlainString()} $currency"
        }
    val completeness = if (partial) "$known (partial)" else known
    val source = if (retrospective) " (includes retrospective estimates)" else ""
    val missing = if (missingRateModels.isEmpty()) "" else
        "; missing rate for ${missingRateModels.sorted().joinToString(", ")}; configure AI_APPS_PRICING_FILE"
    return completeness + source + missing
}

private fun renderAuditSummary(summary: AiUsageSummary): String {
    val records = summary.audits.sortedBy { it.timestamp }
    if (records.isEmpty()) {
        val hasAuditDetailMarker = summary.metrics.any { metric ->
            metric.metricName == "quiz10_preparation" &&
                (metric.metricValues["audit_detail_version"] ?: 0L) >= 1L
        }
        return if (hasAuditDetailMarker) {
            "- no rejections recorded\n"
        } else {
            "- detail not recorded (legacy records)\n"
        }
    }

    val grouped = records.groupBy { it.workUnitId ?: "-" }
    return buildString {
        grouped.toSortedMap().forEach { (workUnit, byWorkUnit) ->
            appendLine("- workUnit=$workUnit")
            val byPosition = byWorkUnit.groupBy { it.auditPosition }
            byPosition.toSortedMap(compareBy<Int?> { it == null }.thenBy { it ?: Int.MAX_VALUE }).forEach { (position, scoped) ->
                val header = if (position == null) "global" else "position $position"
                appendLine("  $header:")
                scoped.forEach { record ->
                    val attempt = record.auditAttempt?.let { " attempt=$it" } ?: ""
                    val reason = record.auditReason?.let { " reason=$it" } ?: ""
                    appendLine("    ${record.auditName ?: "audit"}/${record.auditPhase ?: "phase"} -> ${record.auditResult ?: "unknown"}$attempt$reason")
                }
            }
        }
    }
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
