package dev.magullodev.aiapps.tools.monitor.quiz10

import dev.magullodev.aiapps.core.ai.AiUsageRecord
import dev.magullodev.aiapps.tools.monitor.AiCostDeterminability
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
) {
    val developmentCalls: List<AiUsageRecord> get() = allCalls.filterNot { it.operation in preparationOperations }
    val developmentCost: AiUsageCostEstimate get() = if (developmentCalls.isEmpty())
        AiUsageCostEstimate(AiCostDeterminability.KNOWN, cost.currency ?: "USD", BigDecimal.ZERO)
        else aggregateCost(developmentCalls.map(::estimateCallCost))
    val totalCost: AiUsageCostEstimate get() = aggregateCost(allCalls.map(::estimateCallCost))
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
            .takeIf { it > 0 || metrics.any { m -> m.metricValues["audit_detail_version"] ?: 0L >= 1L } }
    val substitutionAttempts: Int get() = metrics.lastOrNull { it.metricName == "quiz10_preparation" }
        ?.metricValues?.get("replacement_attempts")?.toInt()
        ?: audits.count { it.auditPhase == "replacement" }
}

data class Quiz10RollingPoint(val position: Int, val sampleSize: Int, val cost: AiUsageCostEstimate)
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

fun buildQuiz10History(records: List<AiUsageRecord>, window: Int = 50): Quiz10History {
    require(window in setOf(10, 25, 50, 100)) { "Window must be 10, 25, 50 or 100" }
    val tests = records.asSequence().filter { it.application == "quiz10-web" && !it.workUnitId.isNullOrBlank() }
        .groupBy { it.workUnitId!! }.map { (id, grouped) ->
            val ordered = grouped.sortedWith(compareBy<AiUsageRecord> { it.timestamp }.thenBy { it.recordId })
            val calls = ordered.filter { it.type == "ai_call" && it.operation in preparationOperations }
            val metrics = ordered.filter { it.type == "metric" }
            val terminal = metrics.firstOrNull { it.metricName in setOf(GAME_COMPLETED, GAME_PREPARATION_FAILED, GAME_EXECUTION_FAILED) }
            val status = when {
                terminal?.metricName == GAME_COMPLETED -> Quiz10GameStatus.COMPLETED
                terminal != null -> Quiz10GameStatus.FAILED
                metrics.any { it.metricName == GAME_STARTED } -> Quiz10GameStatus.IN_PROGRESS
                else -> Quiz10GameStatus.UNKNOWN
            }
            Quiz10Test(0, id, ordered.first().timestamp, calls, metrics,
                ordered.filter { it.type == "audit" }, aggregateCost(calls.map(::estimateCallCost)),
                ordered.filter { it.type == "ai_call" }, status, terminal?.timestamp)
        }.sortedWith(compareBy<Quiz10Test> { it.startedAt }.thenBy { it.workUnitId })
        .mapIndexed { index, test -> test.copy(position = index + 1) }
    val rolling = tests.indices.map { index ->
        val sample = tests.subList((index - window + 1).coerceAtLeast(0), index + 1)
        Quiz10RollingPoint(index + 1, sample.size, averageCost(sample))
    }
    val current = if (tests.size >= window) averageCost(tests.takeLast(window)) else null
    val previous = if (tests.size >= window * 2) averageCost(tests.dropLast(window).takeLast(window)) else null
    val comparison = if (current?.determinability == AiCostDeterminability.KNOWN &&
        previous?.determinability == AiCostDeterminability.KNOWN && current.currency == previous.currency &&
        current.currency == "USD") {
        val difference = current.amount!!.subtract(previous.amount!!)
        Quiz10Comparison(current, previous, difference, if (previous.amount.signum() == 0) null else
            difference.multiply(BigDecimal(100)).divide(previous.amount, 4, RoundingMode.HALF_UP))
    } else null
    return Quiz10History(tests, rolling, window, comparison)
}

private fun aggregateCost(costs: List<AiUsageCostEstimate>): AiUsageCostEstimate {
    val currencies = costs.mapNotNull { it.currency }.toSet()
    val complete = costs.isNotEmpty() && costs.all { it.determinability == AiCostDeterminability.KNOWN } && currencies.size == 1
    val amounts = costs.mapNotNull { it.amount }
    val state = when {
        complete -> AiCostDeterminability.KNOWN
        amounts.isNotEmpty() -> AiCostDeterminability.PARTIAL
        else -> AiCostDeterminability.NOT_DETERMINABLE
    }
    return AiUsageCostEstimate(state, currencies.singleOrNull(),
        amounts.takeIf { it.isNotEmpty() && currencies.size <= 1 }?.fold(BigDecimal.ZERO, BigDecimal::add))
}

private fun averageCost(tests: List<Quiz10Test>): AiUsageCostEstimate {
    val costs = tests.map { it.cost }
    val total = aggregateCost(costs)
    return total.copy(amount = total.amount?.divide(BigDecimal(tests.size), 12, RoundingMode.HALF_UP))
}

private fun costText(cost: AiUsageCostEstimate): String {
    val value = cost.amount?.setScale(6, RoundingMode.HALF_UP)?.toPlainString()
    return when (cost.determinability) {
        AiCostDeterminability.KNOWN -> "$value ${cost.currency}"
        AiCostDeterminability.PARTIAL -> "${value ?: "unknown"} ${cost.currency ?: ""} (partial)".trim()
        AiCostDeterminability.NOT_DETERMINABLE -> "not determinable"
    }
}

fun formatQuiz10History(history: Quiz10History, width: Int = 80): String = buildString {
    appendLine("Quiz10 preparation cost history (${history.tests.size} tests)")
    appendLine("Rolling average: last ${history.window} tests; early samples use available tests")
    appendLine(renderQuiz10Chart(history.rolling, width))
    val latest = history.rolling.lastOrNull()
    if (latest != null) appendLine("Latest rolling average (n=${latest.sampleSize}): ${costText(latest.cost)}")
    val comparison = history.comparison
    if (comparison == null) appendLine("Comparison with previous ${history.window} tests: unavailable")
    else {
        appendLine("Current ${history.window} average: ${costText(comparison.current)}")
        appendLine("Previous ${history.window} average: ${costText(comparison.previous)}")
        val direction = if (comparison.difference.signum() < 0) "reduction" else "increase"
        appendLine("Change: $direction ${comparison.difference.abs().setScale(6, RoundingMode.HALF_UP)} USD (${comparison.percent?.abs()?.setScale(2, RoundingMode.HALF_UP) ?: "unavailable"}%)")
    }
    val recent = history.tests.takeLast(10).asReversed()
    appendLine("Last 10 tests (n=${recent.size}):")
    recent.forEach { test ->
        appendLine("#${test.position} ${test.workUnitId} ${test.startedAt} status=${test.status} Terra calls=${test.calls.size} input=${test.preparationInputTokens} output=${test.preparationOutputTokens} preparation=${costText(test.cost)} total=${costText(test.totalCost)} rejected=${test.rejectedRows ?: "unknown"} substitutions=${test.substitutionAttempts}")
    }
    if (recent.isNotEmpty()) appendLine("Last ${recent.size} average: ${costText(averageCost(recent))}")
    recent.firstOrNull()?.let { append(formatQuiz10Game(it)) }
}
fun formatQuiz10Game(game: Quiz10Test): String = buildString {
    appendLine("Latest test #${game.position} ${game.workUnitId}: status=${game.status} started=${game.startedAt} finished=${game.finishedAt ?: "-"}")
    appendLine("AI calls=${game.totalCalls} total input=${game.totalInputTokens} output=${game.totalOutputTokens}")
    appendLine("Preparation input=${game.preparationInputTokens} output=${game.preparationOutputTokens}; development input=${game.developmentInputTokens} output=${game.developmentOutputTokens}")
    game.allCalls.forEach { call ->
        appendLine("- ${call.operation} ${call.model ?: "unknown-model"} duration=${call.durationMillis ?: "unknown"}ms input=${call.inputTokens ?: "unknown"} output=${call.outputTokens ?: "unknown"} cost=${costText(estimateCallCost(call))} result=${call.result ?: "unknown"}")
    }
    appendLine("Preparation total: ${costText(game.cost)}")
    appendLine("Development total: ${costText(game.developmentCost)}")
    appendLine("Game total${if (game.status == Quiz10GameStatus.IN_PROGRESS) " so far" else ""}: ${costText(game.totalCost)}")
    if (game.audits.isEmpty()) appendLine(if (game.rejectedRows == 0) "No rejections recorded" else "Audit detail unavailable")
    else game.audits.forEach { audit ->
        appendLine("- ${audit.auditPhase ?: "audit"} position=${audit.auditPosition ?: "unknown"} attempt=${audit.auditAttempt ?: "-"} result=${audit.auditResult ?: "unknown"} reason=${audit.auditReason ?: "-"}")
    }
}


fun renderQuiz10Chart(points: List<Quiz10RollingPoint>, width: Int = 80): String {
    if (points.isEmpty()) return "Chart: no tests recorded"
    val available = width.coerceAtLeast(2)
    val indices = if (points.size <= available) points.indices.toList() else
        (0 until available).map { it.toLong() * (points.size - 1) / (available - 1) }.map(Long::toInt).distinct()
    val chosen = indices.map(points::get)
    val values = chosen.map { it.cost.amount?.takeIf { _ -> it.cost.determinability == AiCostDeterminability.KNOWN && it.cost.currency == "USD" } }
    val max = points.mapNotNull { it.cost.amount?.takeIf { _ -> it.cost.determinability == AiCostDeterminability.KNOWN && it.cost.currency == "USD" } }.maxOrNull() ?: BigDecimal.ZERO
    val height = 8
    val rows = (height downTo 0).map { row ->
        val cells = values.map { value ->
            if (value == null) ' ' else if (max.signum() == 0 && row == 0) '*' else if (max.signum() != 0 &&
                value.multiply(BigDecimal(height)).divide(max, 0, RoundingMode.HALF_UP).toInt() == row) '*' else ' '
        }.joinToString("")
        val axis = if (row == height) max.setScale(6, RoundingMode.HALF_UP).toPlainString() else if (row == 0) "0.000000" else ""
        "${axis.padStart(10)} |$cells"
    }
    return buildString {
        appendLine("Rolling cost chart (USD/test; * known, blank unknown; y starts at zero)")
        rows.forEach(::appendLine)
        appendLine("${" ".repeat(11)}+${"-".repeat(chosen.size)}")
        append("Test #${chosen.first().position} -> #${chosen.last().position}; scale 0 to ${max.setScale(6, RoundingMode.HALF_UP)} USD; ${points.size} points calculated, ${chosen.size} shown")
    }
}
