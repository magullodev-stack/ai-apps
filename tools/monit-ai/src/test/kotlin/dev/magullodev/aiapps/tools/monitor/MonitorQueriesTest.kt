package dev.magullodev.aiapps.tools.monitor

import dev.magullodev.aiapps.core.ai.*
import dev.magullodev.aiapps.tools.monitor.quiz10.*

import dev.magullodev.aiapps.core.config.AiModelsConfig
import dev.magullodev.aiapps.core.config.AppEnvironment
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.HttpResponse
import dev.magullodev.aiapps.core.network.HttpTransport
import dev.magullodev.aiapps.core.network.NetworkError
import java.io.IOException
import java.net.URI
import java.nio.file.Files
import java.nio.file.Path
import kotlin.concurrent.thread
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertContains
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class MonitorQueriesTest {
    private val schema = """{"type":"object","properties":{"answer":{"type":"string"}},"required":["answer"],"additionalProperties":false}"""
    private val request = StructuredGenerationRequest(
        profile = AiProfile.TERRA,
        input = "SECRET_TOKEN_12345 prompt text",
        schemaName = "quiz10_coverage_route_from_plan",
        schemaJson = schema,
        operation = AiUsageOperation.COVERAGE,
    )
    private val config = EnvironmentConfig(
        environment = AppEnvironment.TEST,
        aiBaseUrl = URI("https://api.example.test/base/"),
        aiApiKey = "super-secret-key",
        aiModels = AiModelsConfig("model-luna", "model-mini", "model-terra"),
    )

    @Test
    fun recordsTerraAndLunaCallsAndAllowsGlobalFilters() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(
            usageFile = file,
            ratesByModel = mapOf(
                "model-terra" to ModelRate("USD", "2.00".toBigDecimal(), "8.00".toBigDecimal()),
                "model-luna" to ModelRate("USD", "0.30".toBigDecimal(), "1.20".toBigDecimal()),
            ),
        )

        val terraClient = OpenAiResponsesClient(
            config = config,
            transport = StaticTransport(
                Outcome.Success(
                    HttpResponse(
                        status = 200,
                        headers = emptyMap(),
                        body = """{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"answer\":\"ok\"}"}]}],"usage":{"input_tokens":100,"output_tokens":50,"total_tokens":150}}""",
                    ),
                ),
            ),
            usageMonitor = monitor,
        )

        val lunaClient = OpenAiResponsesClient(
            config = config,
            transport = StaticTransport(
                Outcome.Success(
                    HttpResponse(
                        status = 200,
                        headers = emptyMap(),
                        body = """{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"answer\":\"ok\"}"}]}],"usage":{"input_tokens":10,"output_tokens":5,"total_tokens":15}}""",
                    ),
                ),
            ),
            usageMonitor = monitor,
        )

        AiUsageContextHolder.withContext(AiUsageContext("quiz10-web", "session-1")) {
            terraClient.generate(request)
            lunaClient.generate(
                request.copy(
                    profile = AiProfile.LUNA,
                    schemaName = "quiz10_luna_turn",
                    operation = AiUsageOperation.LUNA,
                ),
            )
        }
        monitor.recordCall(
            AiUsageCallEvent(
                application = "batch-jobs",
                operation = AiUsageOperation.OTHER,
                model = "model-mini",
                durationMillis = 20,
                result = AiUsageCallResult.SUCCESS,
                workUnitId = "job-1",
                inputTokens = 5,
                outputTokens = 2,
                totalTokens = 7,
                usageKnown = true,
            ),
        )

        val summary = AiUsageQueryService(AiUsageRecordRepository(file)).summarize()
        assertEquals(3, summary.calls.size)
        assertEquals(3, summary.successfulCalls)
        assertEquals(0, summary.failedCalls)
        assertEquals(115, summary.totalKnownInputTokens)
        assertEquals(57, summary.totalKnownOutputTokens)
        assertEquals(2, summary.byApplication["quiz10-web"]?.calls)
        assertEquals(1, summary.byApplication["batch-jobs"]?.calls)
        assertTrue(summary.byModel.containsKey("model-terra"))
        assertTrue(summary.byModel.containsKey("model-luna"))
        assertTrue(summary.byOperation.containsKey("coverage"))
        assertTrue(summary.byOperation.containsKey("luna"))

        val filtered = AiUsageQueryService(AiUsageRecordRepository(file)).summarize(
            AiUsageFilter(application = "quiz10-web", operation = "coverage", workUnitId = "session-1"),
        )
        assertEquals(1, filtered.calls.size)
        assertEquals("coverage", filtered.calls.single().operation)
    }

    @Test
    fun marksUndeterminedWhenRatesOrUsageAreMissing() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(usageFile = file, ratesByModel = emptyMap())
        val client = OpenAiResponsesClient(
            config = config,
            transport = StaticTransport(
                Outcome.Success(
                    HttpResponse(
                        status = 200,
                        headers = emptyMap(),
                        body = """{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"answer\":\"ok\"}"}]}]}""",
                    ),
                ),
            ),
            usageMonitor = monitor,
        )

        AiUsageContextHolder.withContext(AiUsageContext("quiz10-web", "session-2")) {
            client.generate(request)
        }

        val summary = AiUsageQueryService(AiUsageRecordRepository(file)).summarize()
        assertTrue(summary.hasPartialOrUndeterminedCost)
        assertTrue(summary.totalCostByCurrency.isEmpty())
    }

    @Test
    fun recordsFailedCallsWithoutUsageAndPersistsAcrossRestart() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(
            usageFile = file,
            ratesByModel = mapOf("model-terra" to ModelRate("USD", "2.00".toBigDecimal(), "8.00".toBigDecimal())),
        )

        val failingClient = OpenAiResponsesClient(
            config = config,
            transport = StaticTransport(Outcome.Failure(NetworkError.TransportFailure(IOException("boom")))),
            usageMonitor = monitor,
        )

        AiUsageContextHolder.withContext(AiUsageContext("quiz10-web", "session-3")) {
            failingClient.generate(request)
        }

        val repo = AiUsageRecordRepository(file)
        val firstRead = AiUsageQueryService(repo).summarize()
        val secondRead = AiUsageQueryService(repo).summarize()

        assertEquals(1, firstRead.calls.size)
        assertEquals(0, firstRead.successfulCalls)
        assertEquals(1, firstRead.failedCalls)
        assertEquals(1, secondRead.calls.size)
        assertFalse(firstRead.calls.single().usageKnown ?: true)
    }

    @Test
    fun supportsConcurrentWrites() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(
            usageFile = file,
            ratesByModel = mapOf("model-terra" to ModelRate("USD", "2.00".toBigDecimal(), "8.00".toBigDecimal())),
        )

        val threads = (1..8).map { worker ->
            thread {
                repeat(40) { index ->
                    monitor.recordCall(
                        AiUsageCallEvent(
                            application = "quiz10-web",
                            operation = AiUsageOperation.COVERAGE,
                            model = "model-terra",
                            durationMillis = 10,
                            result = AiUsageCallResult.SUCCESS,
                            workUnitId = "session-$worker",
                            inputTokens = 1,
                            outputTokens = 1,
                            totalTokens = 2,
                            usageKnown = true,
                            errorCode = null,
                        ),
                    )
                    if (index % 10 == 0) {
                        monitor.recordMetric(
                            AiUsageMetricEvent(
                                application = "quiz10-web",
                                metricName = "quiz10_preparation",
                                values = mapOf("replacement_attempts" to index.toLong()),
                                workUnitId = "session-$worker",
                            ),
                        )
                    }
                }
            }
        }
        threads.forEach { it.join() }

        val summary = AiUsageQueryService(AiUsageRecordRepository(file)).summarize()
        assertEquals(320, summary.calls.size)
        assertEquals(32, summary.metrics.size)
    }

    @Test
    fun recordsDoNotContainSecretsOrPromptContent() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(
            usageFile = file,
            ratesByModel = mapOf("model-terra" to ModelRate("USD", "2.00".toBigDecimal(), "8.00".toBigDecimal())),
        )

        val client = OpenAiResponsesClient(
            config = config,
            transport = StaticTransport(
                Outcome.Success(
                    HttpResponse(
                        status = 200,
                        headers = emptyMap(),
                        body = """{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"answer\":\"ok\"}"}]}],"usage":{"input_tokens":1,"output_tokens":1,"total_tokens":2}}""",
                    ),
                ),
            ),
            usageMonitor = monitor,
        )

        AiUsageContextHolder.withContext(AiUsageContext("quiz10-web", "session-4")) {
            client.generate(request)
        }

        val lines = Files.readString(file)
        assertFalse(lines.contains("SECRET_TOKEN_12345"))
        assertFalse(lines.contains("super-secret-key"))
        assertFalse(lines.contains("Authorization"))
        assertTrue(lines.contains("quiz10-web"))
        assertTrue(lines.contains("model-terra"))
    }

     @Test
    fun auditEventsDoNotAffectTokenOrCostTotals() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(
            usageFile = file,
            ratesByModel = mapOf("model-terra" to ModelRate("USD", "2.00".toBigDecimal(), "8.00".toBigDecimal())),
        )

        monitor.recordCall(
            AiUsageCallEvent(
                application = "quiz10-web",
                operation = AiUsageOperation.COVERAGE,
                model = "model-terra",
                durationMillis = 100,
                result = AiUsageCallResult.SUCCESS,
                workUnitId = "wu-2",
                inputTokens = 200,
                outputTokens = 50,
                totalTokens = 250,
                usageKnown = true,
            ),
        )
        monitor.recordAudit(
            AiUsageAuditEvent(
                application = "quiz10-web",
                workUnitId = "wu-2",
                audit = "quiz10_route_validation",
                phase = "route_validation",
                result = AiUsageAuditResult.REJECTED,
                reason = "Issue",
            ),
        )

        val summary = AiUsageQueryService(AiUsageRecordRepository(file)).summarize()
        assertEquals(200, summary.totalKnownInputTokens)
        assertEquals(50, summary.totalKnownOutputTokens)
        assertTrue((summary.totalCostByCurrency["USD"] ?: "0".toBigDecimal()) > java.math.BigDecimal.ZERO)
    }

    // Historical reconstruction is verified with synthetic persisted calls.
    @Test
    fun reconstructsFiveHundredTestsAndRollingWindows() {
        val rate = AiUsageRateSnapshot("USD", "1000000", "0")
        val records = (1..500).flatMap { number ->
            val id = "test-${number.toString().padStart(3, '0')}"
            val time = java.time.Instant.parse("2026-01-01T00:00:00Z").plusSeconds(number.toLong()).toString()
            listOf(
                AiUsageRecord("terra-$number", time, "ai_call", "quiz10-web", id, "coverage", "terra",
                    inputTokens = number.toLong(), outputTokens = 0, rate = rate),
                AiUsageRecord("luna-$number", time, "ai_call", "quiz10-web", id, "luna", "luna",
                    inputTokens = 1000, outputTokens = 0, rate = rate),
                AiUsageRecord("end-$number", time, "metric", "quiz10-web", id, metricName = "quiz10_game_completed"),
            )
        }
        val query = { window: Int -> buildQuiz10History(records, window) }
        for (window in listOf(10, 25, 50, 100)) {
            val history = query(window)
            assertEquals(500, history.tests.size)
            assertEquals(1, history.tests.first().position)
            assertEquals(500, history.tests.last().position)
            assertEquals(window, history.rolling.last().sampleSize)
            assertTrue(history.rolling.last().cost.amount!! > history.tests.last().cost.amount!!)
            assertEquals(window, history.comparison!!.difference.toInt())
            assertEquals(1, history.tests.last().calls.size)
            if (window == 50) {
                val html = renderMonitorPage(history)
                assertContains(html, "<svg")
                assertEquals(500, "<details class=\"execution\"".toRegex().findAll(html).count())
                assertContains(html, "Partida #500 · COMPLETADA")
                assertContains(html, "Partida #1 · COMPLETADA")
                assertFalse(html.contains("test-500"))
            }
        }
    }

    @Test
    fun retainsUnknownCostsAuditsAndFailedPreparation() {
        val records = listOf(
            AiUsageRecord("a", "2026-01-01T00:00:00Z", "ai_call", "quiz10-web", "one", "coverage", "terra", result = "error",
                inputTokens = 2, outputTokens = 0, rate = AiUsageRateSnapshot("USD", "1000000", "0")),
            AiUsageRecord("b", "2026-01-01T00:00:01Z", "ai_call", "quiz10-web", "one", "substitutions", "terra", result = "success",
                inputTokens = 3, outputTokens = 0, rate = AiUsageRateSnapshot("USD", "1000000", "0")),
            AiUsageRecord("c", "2026-01-01T00:00:02Z", "audit", "quiz10-web", "one", auditPhase = "initial_review",
                auditResult = "rejected", auditPosition = 2, auditReason = "incorrect"),
            AiUsageRecord("d", "2026-01-02T00:00:00Z", "ai_call", "quiz10-web", "two", "review", "terra", result = "error"),
        )
        val history = buildQuiz10History(records, 10)
        assertEquals("5", history.tests.first().cost.amount?.stripTrailingZeros()?.toPlainString())
        assertEquals(1, history.tests.first().rejectedRows)
        assertEquals(AiCostDeterminability.NOT_DETERMINABLE, history.tests.last().cost.determinability)
        assertEquals(AiCostDeterminability.NOT_DETERMINABLE, history.rolling.last().cost.determinability)
        assertEquals(2, history.tests.first().audits.single().auditPosition)
        assertContains(renderMonitorPage(history), "Indeterminable")
    }

    @Test
    fun doesNotCombineCurrencies() {
        val records = listOf(
            AiUsageRecord("usd", "2026-01-01T00:00:00Z", "ai_call", "quiz10-web", "mixed", "coverage", "terra",
                inputTokens = 1, outputTokens = 0, rate = AiUsageRateSnapshot("USD", "1000000", "0")),
            AiUsageRecord("eur", "2026-01-01T00:00:01Z", "ai_call", "quiz10-web", "mixed", "review", "terra",
                inputTokens = 1, outputTokens = 0, rate = AiUsageRateSnapshot("EUR", "1000000", "0")),
        )
        val history = buildQuiz10History(records, 10)
        assertEquals(null, history.tests.single().cost.amount)
        assertEquals(AiCostDeterminability.PARTIAL, history.tests.single().cost.determinability)
        assertEquals(null, history.rolling.single().cost.amount)
        assertContains(renderMonitorPage(history), "Indeterminable (parcial)")
    }

    @Test
    fun consolidatesLifecycleAndAllCallCostsWithoutChangingHistoricalChart() {
        val rate = AiUsageRateSnapshot("USD", "1000000", "0")
        fun call(id: String, unit: String, operation: String, tokens: Long, time: String, priced: Boolean = true) =
            AiUsageRecord(id, time, "ai_call", "quiz10-web", unit, operation, "model", result = "success",
                inputTokens = tokens, outputTokens = 0, rate = if (priced) rate else null)
        fun event(id: String, unit: String, name: String, time: String) =
            AiUsageRecord(id, time, "metric", "quiz10-web", unit, metricName = name)
        val records = listOf(
            event("start-1", "active", "quiz10_game_started", "2026-01-01T00:00:00Z"),
            call("coverage", "active", "coverage", 2, "2026-01-01T00:00:01Z"),
            call("retry", "active", "review", 3, "2026-01-01T00:00:02Z"),
            call("luna", "active", "luna", 4, "2026-01-01T00:00:03Z"),
            AiUsageRecord("metric", "2026-01-01T00:00:04Z", "metric", "quiz10-web", "active",
                metricName = "quiz10_preparation", metricValues = mapOf("invalidated_positions" to 2, "replacement_attempts" to 1)),
            event("start-2", "done", "quiz10_game_started", "2026-01-02T00:00:00Z"),
            call("done-call", "done", "coverage", 1, "2026-01-02T00:00:01Z"),
            event("close-2", "done", "quiz10_game_completed", "2026-01-02T00:00:02Z"),
            event("start-3", "failed", "quiz10_game_started", "2026-01-03T00:00:00Z"),
            call("failed-call", "failed", "coverage", 1, "2026-01-03T00:00:01Z", false),
            event("fail-3", "failed", "quiz10_game_preparation_failed", "2026-01-03T00:00:02Z"),
            call("legacy", "old", "coverage", 1, "2025-12-31T00:00:00Z"),
        )
        val history = buildQuiz10History(records, 10)
        val active = history.tests.single { it.workUnitId == "active" }
        assertEquals(Quiz10GameStatus.IN_PROGRESS, active.status)
        assertEquals(3, active.totalCalls)
        assertEquals("5", active.cost.amount?.stripTrailingZeros()?.toPlainString())
        assertEquals("4", active.developmentCost.amount?.stripTrailingZeros()?.toPlainString())
        assertEquals("9", active.totalCost.amount?.stripTrailingZeros()?.toPlainString())
        assertEquals(2, active.rejectedRows)
        assertEquals(1, active.substitutionAttempts)
        assertEquals(Quiz10GameStatus.COMPLETED, history.tests.single { it.workUnitId == "done" }.status)
        assertEquals("2026-01-02T00:00:02Z", history.tests.single { it.workUnitId == "done" }.finishedAt)
        assertEquals(Quiz10GameStatus.FAILED, history.tests.single { it.workUnitId == "failed" }.status)
        assertEquals(AiCostDeterminability.NOT_DETERMINABLE, history.tests.single { it.workUnitId == "failed" }.totalCost.determinability)
        assertEquals(Quiz10GameStatus.UNKNOWN, history.tests.first().status)
        assertEquals(4, history.rolling.size)
        val html = renderMonitorPage(history)
        assertContains(html, "FALLIDA")
        assertContains(html, "9.000000 USD")
        assertContains(html, "Provisional")
    }

    private class StaticTransport(

        private val response: Outcome<HttpResponse, NetworkError>,
    ) : HttpTransport {
        override fun execute(request: dev.magullodev.aiapps.core.network.HttpRequest): Outcome<HttpResponse, NetworkError> = response
    }

    private fun usageFile(): Path {
        val root = Path.of("build", "tmp", "ai-usage-tests")
        Files.createDirectories(root)
        return Files.createTempFile(root, "usage-", ".jsonl")
    }
}
