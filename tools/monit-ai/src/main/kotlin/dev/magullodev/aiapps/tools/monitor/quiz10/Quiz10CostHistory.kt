package dev.magullodev.aiapps.tools.monitor.quiz10

import dev.magullodev.aiapps.core.ai.AiUsageRecord
import dev.magullodev.aiapps.core.ai.ModelRate
import dev.magullodev.aiapps.tools.monitor.AiCostDeterminability
import dev.magullodev.aiapps.tools.monitor.AiCostRateSource
import dev.magullodev.aiapps.tools.monitor.AiUsageCostEstimate
import dev.magullodev.aiapps.tools.monitor.estimateCallCost
import java.math.BigDecimal
import java.math.RoundingMode

private val preparationOperations = setOf("coverage", "review", "substitutions")

enum class Quiz10GameStatus { IN_PROGRESS, COMPLETED, FAILED, UNKNOWN }

private const val GAME_STARTED = "quiz10_game_started"
private const val GAME_COMPLETED = "quiz10_game_completed"
private const val GAME_PREPARATION_FAILED = "quiz10_game_preparation_failed"
private const val GAME_EXECUTION_FAILED = "quiz10_game_execution_failed"

data class Quiz10Test(
    val position: Int,
    val workUnitId: String,
    val startedAt: String,
    val calls: List<AiUsageRecord>,
    val metrics: List<AiUsageRecord>,
    val audits: List<AiUsageRecord>,
    val cost: AiUsageCostEstimate,
    val allCalls: List<AiUsageRecord> = calls,
    val status: Quiz10GameStatus = Quiz10GameStatus.UNKNOWN,
    val finishedAt: String? = null,
    val ratesByModel: Map<String, ModelRate> = emptyMap(),
) {
    val developmentCalls: List<AiUsageRecord> get() = allCalls.filterNot { it.operation in preparationOperations }
    val developmentCost: AiUsageCostEstimate get() = aggregateCost(developmentCalls.map { estimateCallCost(it, ratesByModel) })
    val totalCost: AiUsageCostEstimate get() = aggregateCost(allCalls.map { estimateCallCost(it, ratesByModel) })
    val preparationInputTokens: Long get() = calls.mapNotNull { it.inputTokens }.sum()
    val preparationOutputTokens: Long get() = calls.mapNotNull { it.outputTokens }.sum()
    val developmentInputTokens: Long get() = developmentCalls.mapNotNull { it.inputTokens }.sum()
    val developmentOutputTokens: Long get() = developmentCalls.mapNotNull { it.outputTokens }.sum()
    val totalInputTokens: Long get() = allCalls.mapNotNull { it.inputTokens }.sum()
    val totalOutputTokens: Long get() = allCalls.mapNotNull { it.outputTokens }.sum()
    val totalCalls: Int get() = allCalls.size
    val rejectedRows: Int? get() = metrics.lastOrNull { it.metricName == "quiz10_preparation" }
        ?.metricValues?.let { it["invalidated_positions"] ?: it["invalidated_questions"] }?.toInt()
        ?: audits.count { it.auditPhase == "initial_review" && it.auditResult == "rejected" }
            .takeIf { it > 0 || metrics.any { m -> (m.metricValues["audit_detail_version"] ?: 0L) >= 1L } }
    val substitutionAttempts: Int get() = metrics.lastOrNull { it.metricName == "quiz10_preparation" }
        ?.metricValues?.get("replacement_attempts")?.toInt()
        ?: audits.count { it.auditPhase == "replacement" }
}

data class Quiz10RollingPoint(
    val position: Int,
    val sampleSize: Int,
    val cost: AiUsageCostEstimate,
    val individualCost: AiUsageCostEstimate,
    val status: Quiz10GameStatus,
)

data class Quiz10Comparison(
    val current: AiUsageCostEstimate,
    val previous: AiUsageCostEstimate,
    val difference: BigDecimal,
    val percent: BigDecimal?,
)

data class Quiz10History(
    val tests: List<Quiz10Test>,
    val rolling: List<Quiz10RollingPoint>,
    val window: Int,
    val comparison: Quiz10Comparison?,
)

fun buildQuiz10History(
    records: List<AiUsageRecord>,
    window: Int = 50,
    ratesByModel: Map<String, ModelRate> = emptyMap(),
): Quiz10History {
    require(window in setOf(10, 25, 50, 100)) { "Window must be 10, 25, 50 or 100" }
    val tests = records.asSequence().filter { it.application == "quiz10-web" && !it.workUnitId.isNullOrBlank() }
        .groupBy { it.workUnitId!! }.map { (id, grouped) ->
            val ordered = grouped.sortedWith(compareBy<AiUsageRecord> { it.timestamp }.thenBy { it.recordId })
            val allCalls = ordered.filter { it.type == "ai_call" }
            val calls = allCalls.filter { it.operation in preparationOperations }
            val metrics = ordered.filter { it.type == "metric" }
            val terminal = metrics.firstOrNull { it.metricName in setOf(GAME_COMPLETED, GAME_PREPARATION_FAILED, GAME_EXECUTION_FAILED) }
            val status = when {
                terminal?.metricName == GAME_COMPLETED -> Quiz10GameStatus.COMPLETED
                terminal != null -> Quiz10GameStatus.FAILED
                metrics.any { it.metricName == GAME_STARTED } -> Quiz10GameStatus.IN_PROGRESS
                else -> Quiz10GameStatus.UNKNOWN
            }
            Quiz10Test(0, id, ordered.first().timestamp, calls, metrics,
                ordered.filter { it.type == "audit" },
                aggregateCost(calls.map { estimateCallCost(it, ratesByModel) }),
                allCalls, status, terminal?.timestamp, ratesByModel)
        }.sortedWith(compareBy<Quiz10Test> { it.startedAt }.thenBy { it.workUnitId })
        .mapIndexed { index, test -> test.copy(position = index + 1) }
    val closed = tests.filter { it.status == Quiz10GameStatus.COMPLETED || it.status == Quiz10GameStatus.FAILED }
    val rolling = tests.map { test ->
        val sample = closed.takeWhile { it.position <= test.position }.takeLast(window)
        Quiz10RollingPoint(test.position, sample.size,
            if (sample.size < window) unavailableCost() else averageTotalCost(sample), test.totalCost, test.status)
    }
    val currentTests = closed.takeLast(window)
    val previousTests = closed.dropLast(window).takeLast(window)
    val current = if (currentTests.size == window) averageTotalCost(currentTests) else null
    val previous = if (previousTests.size == window) averageTotalCost(previousTests) else null
    val comparison = if (current?.determinability == AiCostDeterminability.KNOWN &&
        previous?.determinability == AiCostDeterminability.KNOWN && current.currency == previous.currency &&
        current.currency == "USD") {
        val difference = current.amount!!.subtract(previous.amount!!)
        Quiz10Comparison(current, previous, difference, if (previous.amount.signum() == 0) null else
            difference.multiply(BigDecimal(100)).divide(previous.amount, 4, RoundingMode.HALF_UP))
    } else null
    return Quiz10History(tests, rolling, window, comparison)
}

internal fun aggregateCost(costs: List<AiUsageCostEstimate>): AiUsageCostEstimate {
    val currencies = costs.mapNotNull { it.currency }.toSet()
    val complete = costs.isNotEmpty() && costs.all { it.determinability == AiCostDeterminability.KNOWN } && currencies.size == 1
    val amounts = costs.mapNotNull { it.amount }
    val state = when {
        complete -> AiCostDeterminability.KNOWN
        amounts.isNotEmpty() -> AiCostDeterminability.PARTIAL
        else -> AiCostDeterminability.NOT_DETERMINABLE
    }
    val source = when {
        costs.any { it.rateSource == AiCostRateSource.RETROSPECTIVE } -> AiCostRateSource.RETROSPECTIVE
        costs.isNotEmpty() && costs.all { it.rateSource == AiCostRateSource.SNAPSHOT } -> AiCostRateSource.SNAPSHOT
        else -> AiCostRateSource.UNKNOWN
    }
    return AiUsageCostEstimate(state, currencies.singleOrNull(),
        amounts.takeIf { it.isNotEmpty() && currencies.size <= 1 }?.fold(BigDecimal.ZERO, BigDecimal::add),
        source, costs.flatMap { it.missingRateModels }.toSet())
}

private fun averageTotalCost(tests: List<Quiz10Test>): AiUsageCostEstimate {
    val total = aggregateCost(tests.map { it.totalCost })
    return total.copy(amount = total.amount?.divide(BigDecimal(tests.size), 12, RoundingMode.HALF_UP))
}

private fun unavailableCost() = AiUsageCostEstimate(AiCostDeterminability.NOT_DETERMINABLE, null, null)
