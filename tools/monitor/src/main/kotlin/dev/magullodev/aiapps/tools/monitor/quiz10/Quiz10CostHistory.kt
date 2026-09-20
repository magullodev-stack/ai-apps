package dev.magullodev.aiapps.tools.monitor.quiz10

import dev.magullodev.aiapps.core.ai.AiUsageRecord
import dev.magullodev.aiapps.core.ai.ModelRate
import dev.magullodev.aiapps.tools.monitor.AiCostDeterminability
import dev.magullodev.aiapps.tools.monitor.AiCostRateSource
import dev.magullodev.aiapps.tools.monitor.AiUsageCostEstimate
import dev.magullodev.aiapps.tools.monitor.estimateCallCost
import java.math.BigDecimal
import java.math.RoundingMode
import java.text.NumberFormat
import java.util.Locale

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
            if (sample.isEmpty()) unavailableCost() else averageTotalCost(sample), test.totalCost, test.status)
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

private fun aggregateCost(costs: List<AiUsageCostEstimate>): AiUsageCostEstimate {
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

private fun costText(cost: AiUsageCostEstimate): String {
    val value = cost.amount?.setScale(6, RoundingMode.HALF_UP)?.toPlainString()
    val amount = when (cost.determinability) {
        AiCostDeterminability.KNOWN -> "$value ${cost.currency}"
        AiCostDeterminability.PARTIAL -> "${value ?: "unknown"} ${cost.currency ?: ""} (partial)".trim()
        AiCostDeterminability.NOT_DETERMINABLE -> "not determinable"
    }
    val source = when (cost.rateSource) {
        AiCostRateSource.SNAPSHOT -> " (historical rate)"
        AiCostRateSource.RETROSPECTIVE -> " (retrospective estimate)"
        AiCostRateSource.UNKNOWN -> ""
    }
    val missing = if (cost.missingRateModels.isEmpty()) "" else
        "; missing rate for ${cost.missingRateModels.sorted().joinToString(", ")}; configure AI_APPS_PRICING_FILE"
    return amount + source + missing
}

private fun tokenText(calls: List<AiUsageRecord>, input: Boolean): String {
    val values = calls.map { if (input) it.inputTokens else it.outputTokens }
    val known = NumberFormat.getIntegerInstance(Locale.GERMANY).format(values.filterNotNull().sum())
    return known + if (values.any { it == null }) " (partial)" else ""
}

fun formatQuiz10History(history: Quiz10History, width: Int = 80): String = buildString {
    appendLine("Quiz10 total AI cost history (${history.tests.size} games)")
    appendLine("Rolling average of total game cost: last ${history.window} closed games; early samples use available closed games")
    appendLine(renderQuiz10Chart(history.rolling, width))
    val latest = history.rolling.lastOrNull()
    if (latest != null) appendLine("Latest rolling average (n=${latest.sampleSize}): ${if (latest.sampleSize == 0) "unavailable" else costText(latest.cost)}")
    val comparison = history.comparison
    if (comparison == null) appendLine("Comparison with previous ${history.window} closed games: unavailable")
    else {
        appendLine("Current ${history.window} closed-game average: ${costText(comparison.current)}")
        appendLine("Previous ${history.window} closed-game average: ${costText(comparison.previous)}")
        val direction = if (comparison.difference.signum() < 0) "reduction" else "increase"
        appendLine("Change: $direction ${comparison.difference.abs().setScale(6, RoundingMode.HALF_UP)} USD (${comparison.percent?.abs()?.setScale(2, RoundingMode.HALF_UP) ?: "unavailable"}%)")
    }
    val recent = history.tests.takeLast(10).asReversed()
    appendLine("Last 10 games (n=${recent.size}):")
    recent.forEach { game ->
        appendLine("#${game.position} ${game.workUnitId} ${game.startedAt} status=${game.status}${if (game.status == Quiz10GameStatus.IN_PROGRESS) " (provisional)" else ""} calls=${game.totalCalls} input=${tokenText(game.allCalls, true)} output=${tokenText(game.allCalls, false)} total=${costText(game.totalCost)} rejected=${game.rejectedRows ?: "unknown"} substitutions=${game.substitutionAttempts}")
    }
    val recentClosed = recent.filter { it.status == Quiz10GameStatus.COMPLETED || it.status == Quiz10GameStatus.FAILED }
    appendLine("Last 10 closed-game average (n=${recentClosed.size}): ${if (recentClosed.isEmpty()) "unavailable" else costText(averageTotalCost(recentClosed))}")
    recent.firstOrNull()?.let { append(formatQuiz10Game(it)) }
}

fun formatQuiz10Game(game: Quiz10Test): String = buildString {
    appendLine("Latest test #${game.position} ${game.workUnitId}: status=${game.status} started=${game.startedAt} finished=${game.finishedAt ?: "-"}")
    appendLine("PARTIDA: ${game.workUnitId}")
    appendLine("ESTADO: ${game.status}${if (game.status == Quiz10GameStatus.IN_PROGRESS) " (provisional)" else ""}")
    appendLine("MODELO | OPERACIÓN | ENTRADA | SALIDA | COSTE | DURACIÓN | RESULTADO")
    game.allCalls.forEach { call ->
        appendLine("${call.model ?: "unknown-model"} | ${call.operation ?: "unknown-operation"} | ${call.inputTokens ?: "unknown"} | ${call.outputTokens ?: "unknown"} | ${costText(estimateCallCost(call, game.ratesByModel))} | ${call.durationMillis ?: "unknown"}ms | ${call.result ?: "unknown"}")
    }
    if (game.calls.isNotEmpty()) appendLine("Preparation total: ${costText(game.cost)}")
    if (game.developmentCalls.isNotEmpty()) appendLine("Development total: ${costText(game.developmentCost)}")
    appendLine("TOTAL PARTIDA${if (game.status == Quiz10GameStatus.IN_PROGRESS) " (acumulado provisional)" else ""}: ${costText(game.totalCost)}")
    appendLine("Entrada: ${tokenText(game.allCalls, true)} tokens")
    appendLine("Salida: ${tokenText(game.allCalls, false)} tokens")
    if (game.audits.isEmpty()) appendLine(if (game.rejectedRows == 0) "No rejections recorded" else "Audit detail unavailable")
    else game.audits.forEach { audit ->
        appendLine("- ${audit.auditPhase ?: "audit"} position=${audit.auditPosition ?: "unknown"} attempt=${audit.auditAttempt ?: "-"} result=${audit.auditResult ?: "unknown"} reason=${audit.auditReason ?: "-"}")
    }
}

fun renderQuiz10Chart(points: List<Quiz10RollingPoint>, width: Int = 80): String {
    if (points.isEmpty()) return "Chart: no games recorded"
    val available = width.coerceAtLeast(2)
    val indices = if (points.size <= available) points.indices.toList() else
        (0 until available).map { it.toLong() * (points.size - 1) / (available - 1) }.map(Long::toInt).distinct()
    val chosen = indices.map(points::get)
    fun plotted(cost: AiUsageCostEstimate): BigDecimal? =
        cost.amount?.takeIf { cost.determinability == AiCostDeterminability.KNOWN && cost.currency == "USD" }
    val max = points.flatMap { point -> listOfNotNull(plotted(point.individualCost), plotted(point.cost)) }
        .maxOrNull() ?: BigDecimal.ZERO
    val height = 8
    fun panel(title: String, values: List<BigDecimal?>, symbols: List<Char>): String = buildString {
        appendLine(title)
        (height downTo 0).forEach { row ->
            val cells = values.mapIndexed { index, value ->
                if (value == null) ' ' else if (max.signum() == 0 && row == 0) symbols[index] else if (max.signum() != 0 &&
                    value.multiply(BigDecimal(height)).divide(max, 0, RoundingMode.HALF_UP).toInt() == row) symbols[index] else ' '
            }.joinToString("")
            val axis = if (row == height) max.setScale(6, RoundingMode.HALF_UP).toPlainString() else if (row == 0) "0.000000" else ""
            appendLine("${axis.padStart(10)} |$cells")
        }
        appendLine("${" ".repeat(11)}+${"-".repeat(chosen.size)}")
    }
    val symbols = chosen.map { point -> when (point.status) {
        Quiz10GameStatus.COMPLETED -> 'C'
        Quiz10GameStatus.FAILED -> 'F'
        Quiz10GameStatus.IN_PROGRESS -> 'P'
        Quiz10GameStatus.UNKNOWN -> 'U'
    } }
    return buildString {
        appendLine("Total game cost chart (USD/game; y starts at zero)")
        append(panel("Individual game: C completed, F failed, P in progress, U unknown status; blank indeterminable",
            chosen.map { plotted(it.individualCost) }, symbols))
        append(panel("Rolling average of closed games: * measured, blank unavailable or indeterminable",
            chosen.map { plotted(it.cost) }, chosen.map { '*' }))
        append("Game #${chosen.first().position} -> #${chosen.last().position}; scale 0 to ${max.setScale(6, RoundingMode.HALF_UP)} USD; ${points.size} points calculated, ${chosen.size} shown")
    }
}
