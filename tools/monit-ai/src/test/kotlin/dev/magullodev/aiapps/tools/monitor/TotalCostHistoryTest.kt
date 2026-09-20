package dev.magullodev.aiapps.tools.monitor

import dev.magullodev.aiapps.core.ai.AiUsageRateSnapshot
import dev.magullodev.aiapps.core.ai.AiUsageRecord
import dev.magullodev.aiapps.core.ai.ModelRate
import dev.magullodev.aiapps.tools.monitor.quiz10.Quiz10GameStatus
import dev.magullodev.aiapps.tools.monitor.quiz10.buildQuiz10History
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
        val html = renderMonitorPage(history)
        assertContains(html, "<svg")
        assertContains(html, "<td>terra</td><td>1423</td><td>1778</td><td>1423.000000 USD</td><td>3556.000000 USD</td><td>4979.000000 USD</td>")
        assertContains(html, "Partida #1 · COMPLETADA")
        assertContains(html, "COSTE TOTAL <strong>4979.000000 USD</strong>")
        assertFalse(html.contains("TOTAL PARTIDA"))
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
        assertEquals(0, live.rolling.single().individualCost.amount!!.compareTo(BigDecimal("14")))
        assertEquals(0, live.rolling.single().sampleSize)
        assertNull(live.rolling.single().cost.amount)
        val html = renderMonitorPage(live)
        assertContains(html, "<svg")
        assertContains(html, "14.000000 USD")
        assertContains(html, "Provisional")
        assertContains(html, "Retrospectivo")
        assertContains(html, "<td>mini</td><td>3</td><td>0</td><td>9.000000 USD")

        val updatedRecords = initial + call("m2", "game", 4, "mini", "other", 2, 0)
        val updated = buildQuiz10History(updatedRecords, 10, rates)
        assertEquals(0, updated.tests.single().totalCost.amount!!.compareTo(BigDecimal("20")))
        assertEquals(0, updated.rolling.single().individualCost.amount!!.compareTo(BigDecimal("20")))
        assertNull(updated.rolling.single().cost.amount)
        val closed = buildQuiz10History(updatedRecords + event("end", "game", 5, "quiz10_game_completed"), 10, rates)
        assertEquals(Quiz10GameStatus.COMPLETED, closed.tests.single().status)
        assertEquals(1, closed.rolling.single().sampleSize)
        assertEquals(0, closed.rolling.single().cost.amount!!.compareTo(BigDecimal("20")))
        assertContains(renderMonitorPage(closed), "Media móvil de partidas cerradas")
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
        assertEquals(AiCostDeterminability.PARTIAL, history.rolling.single().individualCost.determinability)
        assertNull(history.rolling.single().cost.amount)
        assertNull(history.comparison)
        val html = renderMonitorPage(history)
        assertContains(html, "Sin tarifa: mini")
        assertContains(html, "(parcial)")
        assertFalse(html.contains("class=\"individual-point\" cx="))
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
        assertContains(renderMonitorPage(history), "Partida #20 · COMPLETADA")
    }

    @Test
    fun individualHistoryKeepsClosedLiveAndUnknownButOnlyClosedContributesToAverage() {
        val rate = AiUsageRateSnapshot("USD", "1000000", "0")
        val records = listOf(
            call("closed-call", "closed", 1, "terra", "coverage", 2, 0, rate),
            event("closed-end", "closed", 2, "quiz10_game_completed"),
            event("live-start", "live", 3, "quiz10_game_started"),
            call("live-call", "live", 4, "luna", "play", 5, 0, rate),
            call("unknown-call", "unknown", 5, "mini", "play", 7, 0, rate),
        )
        val history = buildQuiz10History(records, 10)
        assertEquals(listOf("closed", "live", "unknown"), history.tests.map { it.workUnitId })
        assertEquals(listOf(1, 1, 1), history.rolling.map { it.sampleSize })
        assertEquals(listOf("2", "5", "7"), history.rolling.map { it.individualCost.amount!!.stripTrailingZeros().toPlainString() })
        assertTrue(history.rolling.all { it.cost.amount!!.compareTo(BigDecimal("2")) == 0 })
        val html = renderMonitorPage(history)
        assertContains(html, "<svg")
        assertContains(html, "Partida #3 · ESTADO DESCONOCIDO")
        assertContains(html, "COSTE ACUMULADO <strong>14.000000 USD")
        assertEquals(1, "<details class=\"product\"".toRegex().findAll(html).count())
        assertEquals(3, "<details class=\"execution\"".toRegex().findAll(html).count())
        assertTrue(html.indexOf("<details class=\"product\"") < html.indexOf("<svg"))
        assertTrue(html.indexOf("<svg") < html.indexOf("Partida #3"))
        assertTrue(html.indexOf("Partida #3") < html.indexOf("Partida #2"))
        assertTrue(html.indexOf("Partida #2") < html.indexOf("Partida #1"))
        assertFalse(html.contains("unknown-call"))
        assertContains(html, "Media móvil de partidas cerradas")
    }

    @Test
    fun failedGameContributesItsRecordedCostToClosedAverage() {
        val rate = AiUsageRateSnapshot("USD", "1000000", "0")
        val history = buildQuiz10History(listOf(
            call("failed-call", "failed", 1, "terra", "coverage", 4, 0, rate),
            event("failed-end", "failed", 2, "quiz10_game_preparation_failed"),
        ), 10)
        assertEquals(Quiz10GameStatus.FAILED, history.tests.single().status)
        assertEquals(1, history.rolling.single().sampleSize)
        assertEquals(0, history.rolling.single().cost.amount!!.compareTo(BigDecimal("4")))
        assertContains(renderMonitorPage(history), "Partida #1 · FALLIDA")
    }

    @Test
    fun allWindowSizesAndComparisonsSkipInterleavedOpenAndUnknownGames() {
        val rate = AiUsageRateSnapshot("USD", "1000000", "0")
        val records = (1..200).flatMap { n ->
            val unit = "closed-${n.toString().padStart(3, '0')}"
            listOf(
                call("call-$n", unit, 1, "terra", "coverage", n.toLong(), 0, rate).copy(timestamp = "2026-01-${(n / 24 + 1).toString().padStart(2, '0')}T${(n % 24).toString().padStart(2, '0')}:00:00Z"),
                event("end-$n", unit, 2, if (n % 2 == 0) "quiz10_game_completed" else "quiz10_game_execution_failed")
                    .copy(timestamp = "2026-01-${(n / 24 + 1).toString().padStart(2, '0')}T${(n % 24).toString().padStart(2, '0')}:00:01Z"),
            )
        } + listOf(
            event("live-start", "live-last", 1, "quiz10_game_started").copy(timestamp = "2026-02-01T00:00:00Z"),
            call("live-call", "live-last", 2, "luna", "play", 999, 0, rate).copy(timestamp = "2026-02-01T00:00:01Z"),
            call("unknown-call", "unknown-last", 3, "mini", "play", 888, 0, rate).copy(timestamp = "2026-02-01T00:00:02Z"),
        )
        for (window in listOf(10, 25, 50, 100)) {
            val history = buildQuiz10History(records, window)
            assertEquals(202, history.tests.size)
            assertEquals(window, history.rolling.last().sampleSize)
            assertEquals(0, history.rolling.last().cost.amount!!.compareTo(BigDecimal(200 - (window - 1) / 2.0).setScale(1)))
            assertEquals(0, history.comparison!!.difference.compareTo(BigDecimal(window)))
            assertEquals(Quiz10GameStatus.UNKNOWN, history.rolling.last().status)
            assertEquals(0, history.rolling.last().individualCost.amount!!.compareTo(BigDecimal("888")))
        }
    }

    @Test
    fun incompleteClosedCostBlocksAverageAndComparisonWithoutPlottingZero() {
        val rate = AiUsageRateSnapshot("USD", "1000000", "0")
        val records = (1..20).flatMap { n ->
            val unit = "game-$n"
            listOf(
                call("call-$n", unit, 1, "terra", "coverage", 1, 0, if (n == 20) null else rate)
                    .copy(timestamp = "2026-01-${n.toString().padStart(2, '0')}T00:00:00Z"),
                event("end-$n", unit, 2, "quiz10_game_completed")
                    .copy(timestamp = "2026-01-${n.toString().padStart(2, '0')}T00:00:01Z"),
            )
        }
        val history = buildQuiz10History(records, 10)
        assertEquals(AiCostDeterminability.PARTIAL, history.rolling.last().cost.determinability)
        assertNull(history.comparison)
        assertContains(renderMonitorPage(history), "Indeterminable")
        assertEquals(AiCostDeterminability.NOT_DETERMINABLE, history.rolling.last().individualCost.determinability)
    }

    @Test
    fun missingInputUsageKeepsSeparateOutputAndPartialTotal() {
        val record = call("partial", "game", 1, "terra", "coverage", 0, 1,
            AiUsageRateSnapshot("USD", "1000000", "2000000")).copy(inputTokens = null)
        val costs = estimateCallCosts(record)
        assertEquals(AiCostDeterminability.NOT_DETERMINABLE, costs.input.determinability)
        assertEquals(0, costs.output.amount!!.compareTo(BigDecimal("2")))
        assertEquals(AiCostDeterminability.PARTIAL, costs.total.determinability)
        val html = renderMonitorPage(buildQuiz10History(listOf(record), 10))
        assertContains(html, "<td>terra</td><td>—</td><td>1</td><td>Indeterminable</td><td>2.000000 USD</td><td>2.000000 USD (parcial)</td>")
    }

    @Test
    fun historicalSnapshotOverridesLaterConfiguredRate() {
        val record = call("old", "game", 1, "terra", "review", 1, 0,
            AiUsageRateSnapshot("USD", "1000000", "0"))
        val configured = mapOf("terra" to ModelRate("USD", BigDecimal("99000000"), BigDecimal.ZERO))
        val estimate = estimateCallCost(record, configured)
        assertEquals(0, estimate.amount!!.compareTo(BigDecimal.ONE))
        assertEquals(AiCostRateSource.SNAPSHOT, estimate.rateSource)
        val costs = estimateCallCosts(record, configured)
        assertEquals(0, costs.input.amount!!.compareTo(BigDecimal.ONE))
        assertEquals(0, costs.output.amount!!.compareTo(BigDecimal.ZERO))
        val history = buildQuiz10History(listOf(record), 10, configured)
        assertContains(renderMonitorPage(history), "1.000000 USD")
    }
}
