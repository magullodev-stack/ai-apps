package dev.magullodev.aiapps.tools.monitor

import dev.magullodev.aiapps.core.ai.AiUsageRateSnapshot
import dev.magullodev.aiapps.core.ai.AiUsageRecord
import dev.magullodev.aiapps.core.ai.ModelRate
import dev.magullodev.aiapps.tools.monitor.quiz10.Quiz10GameStatus
import dev.magullodev.aiapps.tools.monitor.quiz10.buildQuiz10History
import dev.magullodev.aiapps.tools.monitor.quiz10.formatQuiz10Game
import dev.magullodev.aiapps.tools.monitor.quiz10.formatQuiz10History
import dev.magullodev.aiapps.tools.monitor.quiz10.renderQuiz10Chart
import java.math.BigDecimal
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class TotalCostHistoryTest {
    private fun call(
        id: String,
        unit: String,
        second: Int,
        model: String,
        operation: String,
        input: Long,
        output: Long,
        rate: AiUsageRateSnapshot? = null,
    ) = AiUsageRecord(id, "2026-01-01T00:00:${second.toString().padStart(2, '0')}Z", "ai_call", "quiz10-web",
        unit, operation, model, result = "success", inputTokens = input, outputTokens = output, rate = rate)

    private fun event(id: String, unit: String, second: Int, name: String) = AiUsageRecord(
        id, "2026-01-01T00:00:${second.toString().padStart(2, '0')}Z", "metric", "quiz10-web", unit,
        metricName = name,
    )

    @Test
    fun twoTerraCallsProduceTheOnlyTwoRowsAndTheirExactTotal() {
        val rate = AiUsageRateSnapshot("USD", "1000000", "2000000")
        val history = buildQuiz10History(listOf(
            call("coverage", "game", 1, "terra", "coverage", 442, 938, rate),
            call("review", "game", 2, "terra", "review", 981, 840, rate),
            event("end", "game", 3, "quiz10_game_completed"),
        ), 10)
        val game = history.tests.single()
        assertEquals(2, game.totalCalls)
        assertEquals(1423, game.totalInputTokens)
        assertEquals(1778, game.totalOutputTokens)
        assertEquals(0, game.totalCost.amount!!.compareTo(BigDecimal("4979")))
        assertEquals(0, history.rolling.single().cost.amount!!.compareTo(game.totalCost.amount))
        val detail = formatQuiz10Game(game)
        assertContains(detail, "terra | coverage | 442 | 938 | 2318.000000 USD (historical rate)")
        assertContains(detail, "terra | review | 981 | 840 | 2661.000000 USD (historical rate)")
        assertContains(detail, "TOTAL PARTIDA: 4979.000000 USD (historical rate)")
        assertContains(detail, "Entrada: 1.423 tokens")
        assertContains(detail, "Salida: 1.778 tokens")
        assertFalse(detail.contains("Development total:"))
        assertContains(renderQuiz10Chart(history.rolling), "4979.000000")
    }

    @Test
    fun liveGameAccumulatesEveryModelAndRollingPointUpdatesUntilClosure() {
        val terra = AiUsageRateSnapshot("USD", "1000000", "0")
        val luna = AiUsageRateSnapshot("USD", "2000000", "0")
        val rates = mapOf("mini" to ModelRate("USD", BigDecimal("3000000"), BigDecimal.ZERO))
        val initial = listOf(
            event("start", "game", 0, "quiz10_game_started"),
            call("t", "game", 1, "terra", "coverage", 1, 0, terra),
            call("l", "game", 2, "luna", "luna", 2, 0, luna),
            call("m", "game", 3, "mini", "other", 3, 0),
        )
        val live = buildQuiz10History(initial, 10, rates)
        assertEquals(Quiz10GameStatus.IN_PROGRESS, live.tests.single().status)
        assertEquals(0, live.tests.single().totalCost.amount!!.compareTo(BigDecimal("14")))
        assertEquals(0, live.rolling.single().cost.amount!!.compareTo(BigDecimal("14")))
        assertTrue(live.rolling.single().provisional)
        assertContains(formatQuiz10History(live), "Latest rolling average (provisional)")
        assertContains(formatQuiz10Game(live.tests.single()), "TOTAL PARTIDA (acumulado provisional): 14.000000 USD (retrospective estimate)")
        assertContains(formatQuiz10Game(live.tests.single()), "mini | other | 3 | 0 | 9.000000 USD (retrospective estimate)")

        val updatedRecords = initial + call("m2", "game", 4, "mini", "other", 2, 0)
        val updated = buildQuiz10History(updatedRecords, 10, rates)
        assertEquals(0, updated.tests.single().totalCost.amount!!.compareTo(BigDecimal("20")))
        assertEquals(0, updated.rolling.single().cost.amount!!.compareTo(BigDecimal("20")))
        assertTrue(updated.rolling.single().provisional)
        val closed = buildQuiz10History(updatedRecords + event("end", "game", 5, "quiz10_game_completed"), 10, rates)
        assertEquals(Quiz10GameStatus.COMPLETED, closed.tests.single().status)
        assertFalse(closed.rolling.single().provisional)
        assertEquals(0, closed.rolling.single().cost.amount!!.compareTo(BigDecimal("20")))
    }

    @Test
    fun missingRateKeepsTotalAndMovingAverageIncompleteAndNamesModel() {
        val rate = AiUsageRateSnapshot("USD", "1000000", "0")
        val history = buildQuiz10History(listOf(
            call("t", "game", 1, "terra", "coverage", 1, 0, rate),
            call("m", "game", 2, "mini", "other", 1, 0),
        ), 10)
        val total = history.tests.single().totalCost
        assertEquals(AiCostDeterminability.PARTIAL, total.determinability)
        assertEquals(setOf("mini"), total.missingRateModels)
        assertEquals(AiCostDeterminability.PARTIAL, history.rolling.single().cost.determinability)
        assertNull(history.comparison)
        assertContains(formatQuiz10Game(history.tests.single()), "missing rate for mini; configure AI_APPS_PRICING_FILE")
        assertFalse(renderQuiz10Chart(history.rolling).contains("|*"))
    }

    @Test
    fun consecutiveWindowComparisonUsesTotalGameCost() {
        val rate = AiUsageRateSnapshot("USD", "1000000", "0")
        val records = (1..20).flatMap { n ->
            val game = "game-$n"
            val time = "2026-01-01T00:${n.toString().padStart(2, '0')}:00Z"
            listOf(
                call("terra-$n", game, 1, "terra", "coverage", 1, 0, rate).copy(timestamp = time),
                call("luna-$n", game, 2, "luna", "play", if (n <= 10) 1 else 2, 0, rate).copy(timestamp = time),
                event("end-$n", game, 3, "quiz10_game_completed").copy(timestamp = time),
            )
        }
        val history = buildQuiz10History(records, 10)
        val comparison = history.comparison!!
        assertEquals(0, comparison.previous.amount!!.compareTo(BigDecimal("2")))
        assertEquals(0, comparison.current.amount!!.compareTo(BigDecimal("3")))
        assertEquals(0, comparison.difference.compareTo(BigDecimal("1")))
        assertEquals(0, comparison.percent!!.compareTo(BigDecimal("50")))
        assertContains(formatQuiz10History(history), "Change: increase 1.000000 USD (50.00%)")
    }

    @Test
    fun historicalSnapshotOverridesLaterConfiguredRate() {
        val record = call("old", "game", 1, "terra", "review", 1, 0,
            AiUsageRateSnapshot("USD", "1000000", "0"))
        val configured = mapOf("terra" to ModelRate("USD", BigDecimal("99000000"), BigDecimal.ZERO))
        val estimate = estimateCallCost(record, configured)
        assertEquals(0, estimate.amount!!.compareTo(BigDecimal.ONE))
        assertEquals(AiCostRateSource.SNAPSHOT, estimate.rateSource)
        val history = buildQuiz10History(listOf(record), 10, configured)
        assertContains(formatQuiz10Game(history.tests.single()), "TOTAL PARTIDA: 1.000000 USD (historical rate)")
    }
}
