package dev.magullodev.aiapps.core.ai

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

class AiUsageMonitorTest {
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
    fun formattingIncludesGlobalAndBreakdownSections() {
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
                durationMillis = 123,
                result = AiUsageCallResult.SUCCESS,
                workUnitId = "session-5",
                inputTokens = 200,
                outputTokens = 100,
                totalTokens = 300,
                usageKnown = true,
            ),
        )
        monitor.recordMetric(
            AiUsageMetricEvent(
                application = "quiz10-web",
                metricName = "quiz10_preparation",
                workUnitId = "session-5",
                values = mapOf(
                    "preparation_duration_ms" to 123,
                    "invalidated_positions" to 1,
                    "replaced_questions" to 1,
                    "replacement_attempts" to 2,
                ),
            ),
        )

        val summary = AiUsageQueryService(AiUsageRecordRepository(file)).summarize()
        val rendered = formatUsageSummary(summary)

        assertTrue(rendered.contains("AI usage monitor"))
        assertTrue(rendered.contains("By application:"))
        assertTrue(rendered.contains("By model:"))
        assertTrue(rendered.contains("By operation:"))
        assertTrue(rendered.contains("Metric events:"))
        assertTrue(rendered.contains("quiz10_preparation"))
        assertTrue(rendered.contains("preparation_duration_ms=123"))
        assertTrue(rendered.contains("replacement_attempts=2"))
        assertTrue(rendered.contains("coverage"))
        assertTrue(rendered.contains("model-terra"))
        assertNotNull(summary.totalCostByCurrency["USD"])
    }

    @Test
    fun formattingShowsAuditEventsByWorkUnitAndPosition() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(
            usageFile = file,
            ratesByModel = mapOf("model-terra" to ModelRate("USD", "2.00".toBigDecimal(), "8.00".toBigDecimal())),
        )

        monitor.recordMetric(
            AiUsageMetricEvent(
                application = "quiz10-web",
                metricName = "quiz10_preparation",
                workUnitId = "wu-1",
                values = mapOf("audit_detail_version" to 1),
            ),
        )
        monitor.recordAudit(
            AiUsageAuditEvent(
                application = "quiz10-web",
                workUnitId = "wu-1",
                audit = "quiz10_question_review",
                phase = "initial_review",
                position = 4,
                result = AiUsageAuditResult.REJECTED,
                reason = "Distractores repetidos",
            ),
        )
        monitor.recordAudit(
            AiUsageAuditEvent(
                application = "quiz10-web",
                workUnitId = "wu-1",
                audit = "quiz10_question_replacement",
                phase = "replacement",
                position = 4,
                attempt = 1,
                result = AiUsageAuditResult.ACCEPTED,
            ),
        )

        val summary = AiUsageQueryService(AiUsageRecordRepository(file)).summarize(
            AiUsageFilter(workUnitId = "wu-1"),
        )
        val rendered = formatUsageSummary(summary)

        assertContains(rendered, "Audit events:")
        assertContains(rendered, "workUnit=wu-1")
        assertContains(rendered, "position 4")
        assertContains(rendered, "quiz10_question_review/initial_review -> rejected")
        assertContains(rendered, "quiz10_question_replacement/replacement -> accepted attempt=1")
    }

    @Test
    fun formattingDistinguishesNoRejectionsFromLegacyWithoutDetail() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(
            usageFile = file,
            ratesByModel = emptyMap(),
        )

        monitor.recordMetric(
            AiUsageMetricEvent(
                application = "quiz10-web",
                metricName = "quiz10_preparation",
                workUnitId = "wu-new",
                values = mapOf("audit_detail_version" to 1, "invalidated_positions" to 0),
            ),
        )
        val withDetail = formatUsageSummary(
            AiUsageQueryService(AiUsageRecordRepository(file)).summarize(
                AiUsageFilter(workUnitId = "wu-new"),
            ),
        )
        assertContains(withDetail, "no rejections recorded")

        monitor.recordMetric(
            AiUsageMetricEvent(
                application = "quiz10-web",
                metricName = "quiz10_preparation",
                workUnitId = "wu-legacy",
                values = mapOf("invalidated_positions" to 0),
            ),
        )
        val legacy = formatUsageSummary(
            AiUsageQueryService(AiUsageRecordRepository(file)).summarize(
                AiUsageFilter(workUnitId = "wu-legacy"),
            ),
        )
        assertContains(legacy, "detail not recorded (legacy records)")
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
