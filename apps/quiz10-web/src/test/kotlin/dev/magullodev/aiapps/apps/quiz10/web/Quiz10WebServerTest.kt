package dev.magullodev.aiapps.apps.quiz10.web

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.AiTransportFailureKind
import dev.magullodev.aiapps.core.ai.AiUsageCallEvent
import dev.magullodev.aiapps.core.ai.AiUsageCallResult
import dev.magullodev.aiapps.core.ai.AiUsageContextHolder
import dev.magullodev.aiapps.core.ai.AiUsageMonitor
import dev.magullodev.aiapps.core.ai.AiUsageOperation
import dev.magullodev.aiapps.core.ai.FileAiUsageMonitor
import dev.magullodev.aiapps.core.ai.ModelRate
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageRouteItem
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.StandardCoveragePlan
import dev.magullodev.aiapps.systems.games.quiz10.random.test.procesamiento.CoverageRouteGenerationError
import dev.magullodev.aiapps.systems.games.quiz10.random.test.procesamiento.CoverageRouteValidationError
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.PreparedQuiz
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.PreparedQuizPreparationMetrics
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.PreparedQuizQuestion
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.QuizPreparationError
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.luna.QuizTurnGenerationError
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preguntas.QuizQuestion
import java.io.ByteArrayOutputStream
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import java.util.concurrent.atomic.AtomicInteger
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class Quiz10WebServerTest {
    private val client = HttpClient.newHttpClient()
    private val defaultSelection = "Historia"
    private val alternativeSelection = "Física"

    @Test
    fun getRootShowsInitialForm() {
        withServer(prepareSuccess()) { baseUrl, _, _ ->
            val response = get("$baseUrl/")

            assertEquals(200, response.statusCode())
            assertContains(response.body(), "Empezar Quiz10")
        }
    }

    @Test
    fun createGameStartsDirectlyOnQuestionOneWithoutLunaPanel() {
        val response = withServer(prepareSuccess()) { baseUrl, _, _ ->
            postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
        }

        assertEquals(200, response.statusCode())
        assertContains(response.body(), "Pregunta 1/10")
        assertFalse(response.body().contains("Luna"))
        assertFalse(response.body().contains("Cargando comentario"))
        assertFalse(response.body().contains("/interaction?"))
    }

    @Test
    fun answerAdvancesQuestionWithoutAutomaticComments() {
        withServer(prepareSuccess()) { baseUrl, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val sessionId = extractSessionId(start.body())

            val answer = postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to "0"))
            assertEquals(200, answer.statusCode())
            assertContains(answer.body(), "Pregunta 2/10")
            assertContains(answer.body(), "CORRECTO")
            assertFalse(answer.body().contains("Luna"))
            assertFalse(answer.body().contains("Cargando comentario"))
            assertFalse(answer.body().contains("/interaction?"))
        }
    }

    @Test
    fun starEarnedIsTrueOnlyOnTenOutOfTen() {
        withServer(prepareSuccess()) { baseUrl, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val sessionId = extractSessionId(start.body())

            var finalBody = ""
            PreparedQuiz.correctOptionSequence.forEachIndexed { index, option ->
                val selected = if (index == 0) (option + 1) % 4 else option
                finalBody = postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to selected.toString())).body()
            }

            assertContains(finalBody, "Puntuación final 9/10")
            assertContains(finalBody, "Estrellas: ⭐ 0")
        }
    }

    @Test
    fun replaySameTopicKeepsProgress() {
        withServer(prepareSuccess()) { baseUrl, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val sessionId = extractSessionId(start.body())
            PreparedQuiz.correctOptionSequence.forEach { option ->
                postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to option.toString()))
            }

            val replay = postForm("$baseUrl/games/$sessionId/navigation", mapOf("selection" to "1"))
            assertContains(replay.body(), "Pregunta 1/10")

            var final = replay.body()
            PreparedQuiz.correctOptionSequence.forEach { option ->
                final = postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to option.toString())).body()
            }

            assertContains(final, "Aciertos acumulados: 20")
            assertContains(final, "Estrellas: ⭐ 2")
        }
    }

    @Test
    fun replaySameTopicPreparationFailurePreservesFinishedGameAndAllowsRetry() {
        val prepareCalls = AtomicInteger(0)
        val prepare: (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError> = { plan ->
            when (prepareCalls.incrementAndGet()) {
                2 -> Outcome.Failure(QuizPreparationError.InvalidCoverageRouteSize(8))
                else -> Outcome.Success(prepared(topicFromPlan(plan)))
            }
        }

        withServer(prepare = prepare) { baseUrl, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val sessionId = extractSessionId(start.body())
            var finished = ""
            PreparedQuiz.correctOptionSequence.forEach { option ->
                finished = postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to option.toString())).body()
            }
            assertContains(finished, "Aciertos acumulados: 10")

            val failedReplay = postForm("$baseUrl/games/$sessionId/navigation", mapOf("selection" to "1"))
            assertEquals(500, failedReplay.statusCode())
            assertContains(failedReplay.body(), "InvalidCoverageRouteSize")
            assertContains(failedReplay.body(), "/games/$sessionId/panel")

            val panel = get("$baseUrl/games/$sessionId/panel")
            assertEquals(200, panel.statusCode())
            assertContains(panel.body(), "Puntuación final 10/10")
            assertContains(panel.body(), "Aciertos acumulados: 10")
            assertContains(panel.body(), "1. 🔂 Otro Quiz10 de Historia")

            val retry = postForm("$baseUrl/games/$sessionId/navigation", mapOf("selection" to "1"))
            assertEquals(200, retry.statusCode())
            assertContains(retry.body(), "Pregunta 1/10")
            assertContains(retry.body(), "Tema:</strong> Historia")
        }
    }

    @Test
    fun chooseAnotherTopicKeepsProgress() {
        withServer(prepareSuccess()) { baseUrl, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val sessionId = extractSessionId(start.body())
            PreparedQuiz.correctOptionSequence.forEach { option ->
                postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to option.toString()))
            }

            val choose = postForm("$baseUrl/games/$sessionId/navigation", mapOf("selection" to "3"))
            assertContains(choose.body(), "Elegir modalidad o área")

            val changed = postForm("$baseUrl/games/$sessionId/topic", mapOf("selection" to alternativeSelection))
            assertContains(changed.body(), "Tema:</strong> Física")

            var final = changed.body()
            PreparedQuiz.correctOptionSequence.forEach { option ->
                final = postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to option.toString())).body()
            }

            assertContains(final, "Aciertos acumulados: 20")
            assertContains(final, "1. 🔂 Otro Quiz10 de Física")
        }
    }

    @Test
    fun chooseAnotherTopicPreparationFailurePreservesFinishedGameAndAllowsRetry() {
        val prepareCalls = AtomicInteger(0)
        val prepare: (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError> = { plan ->
            when (prepareCalls.incrementAndGet()) {
                2 -> Outcome.Failure(QuizPreparationError.CoverageRouteGenerationFailed(CoverageRouteGenerationError.GenerationFailed(AiError.TransportFailure)))
                else -> Outcome.Success(prepared(topicFromPlan(plan)))
            }
        }

        withServer(prepare = prepare) { baseUrl, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val sessionId = extractSessionId(start.body())
            PreparedQuiz.correctOptionSequence.forEach { option ->
                postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to option.toString()))
            }

            val choose = postForm("$baseUrl/games/$sessionId/navigation", mapOf("selection" to "3"))
            assertEquals(200, choose.statusCode())
            assertContains(choose.body(), "Elegir modalidad o área")

            val failedChange = postForm("$baseUrl/games/$sessionId/topic", mapOf("selection" to alternativeSelection))
            assertEquals(500, failedChange.statusCode())
            assertContains(failedChange.body(), "CoverageRouteGenerationFailed")
            assertContains(failedChange.body(), "/games/$sessionId/panel")

            val panel = get("$baseUrl/games/$sessionId/panel")
            assertEquals(200, panel.statusCode())
            assertContains(panel.body(), "Aciertos acumulados: 10")
            assertContains(panel.body(), "1. 🔂 Otro Quiz10 de Historia")

            val chooseAgain = postForm("$baseUrl/games/$sessionId/navigation", mapOf("selection" to "3"))
            assertEquals(200, chooseAgain.statusCode())
            val changed = postForm("$baseUrl/games/$sessionId/topic", mapOf("selection" to alternativeSelection))
            assertEquals(200, changed.statusCode())
            assertContains(changed.body(), "Pregunta 1/10")
            assertContains(changed.body(), "Tema:</strong> Física")
        }
    }

    @Test
    fun reviewFailedAnswersDoesNotChangeProgress() {
        withServer(prepareSuccess()) { baseUrl, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val sessionId = extractSessionId(start.body())

            var finalBody = ""
            PreparedQuiz.correctOptionSequence.forEachIndexed { idx, option ->
                val selected = if (idx == 0) (option + 1) % 4 else option
                finalBody = postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to selected.toString())).body()
            }
            assertContains(finalBody, "Aciertos acumulados: 9")

            val review = postForm("$baseUrl/games/$sessionId/navigation", mapOf("selection" to "4"))
            assertContains(review.body(), "Repaso de respuestas fallidas")
            assertContains(review.body(), "Pregunta 1")

            val panel = get("$baseUrl/games/$sessionId/panel")
            assertContains(panel.body(), "Aciertos acumulados: 9")
            assertContains(panel.body(), "Estrellas: ⭐ 0")
        }
    }

    @Test
    fun missingSessionReturns404() {
        withServer(prepareSuccess()) { baseUrl, _, _ ->
            val response = postForm("$baseUrl/games/missing/answer", mapOf("option" to "0"))

            assertEquals(404, response.statusCode())
            assertContains(response.body(), "Sesión no encontrada")
        }
    }

    @Test
    fun invalidInputReturns400() {
        withServer(prepareSuccess()) { baseUrl, _, _ ->
            val response = postForm("$baseUrl/games", mapOf("name" to "", "selection" to ""))

            assertEquals(400, response.statusCode())
            assertContains(response.body(), "Solicitud inválida")
        }
    }

    @Test
    fun coverageGenerationFailureShowsTypedCoverageMessage() {
        withServer(
            prepareFailure(
                QuizPreparationError.CoverageRouteGenerationFailed(
                    CoverageRouteGenerationError.GenerationFailed(AiError.TransportFailure),
                ),
            ),
        ) { baseUrl, _, _ ->
            val response = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))

            assertEquals(500, response.statusCode())
            val body = response.body()
            assertContains(body, "ruta de cobertura")
            assertContains(body, "CoverageRouteGenerationFailed")
            assertFalse(body.contains("Authorization"))
            assertFalse(body.contains("Bearer"))
        }
    }

    @Test
    fun invalidCoverageRouteSizeIsDistinguishedFromAiFailure() {
        withServer(prepareFailure(QuizPreparationError.InvalidCoverageRouteSize(8))) { baseUrl, _, _ ->
            val response = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))

            assertEquals(500, response.statusCode())
            val body = response.body()
            assertContains(body, "ruta de cobertura")
            assertContains(body, "InvalidCoverageRouteSize")
            assertFalse(body.contains("AiError.TransportFailure"))
            assertFalse(body.contains("Authorization"))
        }
    }

    @Test
    fun rejectedCoverageRouteShowsReadableMessageAndBlocksGameCreation() {
        withServer(
            prepareFailure(
                QuizPreparationError.CoverageRouteValidationFailed(
                    CoverageRouteValidationError.RouteRejected(
                        listOf("La ruta repite referentes sin justificación"),
                    ),
                ),
            ),
        ) { baseUrl, _, _ ->
            val response = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))

            assertEquals(422, response.statusCode())
            val body = response.body()
            assertContains(body, "rechazada por validación semántica")
            assertContains(body, "repite referentes")
            assertFalse(body.contains("Authorization"))
        }
    }

    @Test
    fun diagnosedTransportFailureIsLoggedButNotExposedAndGameDoesNotStart() {
        val diagnosed = AiError.TransportFailureDiagnosed(
            kind = AiTransportFailureKind.CONNECT_TIMEOUT,
            detail = "SocketTimeoutException: connect timed out",
        )

        val originalErr = System.err
        val captured = ByteArrayOutputStream()
        System.setErr(captured.printStream())
        try {
            withServer(
                prepareFailure(
                    QuizPreparationError.StandardCoverageRouteGenerationFailed(
                        CoverageRouteGenerationError.GenerationFailed(diagnosed),
                    ),
                ),
            ) { baseUrl, _, _ ->
                val response = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))

                assertEquals(500, response.statusCode())
                val body = response.body()
                assertContains(body, "ruta de cobertura estándar")
                assertContains(body, "TransportFailure(CONNECT_TIMEOUT)")
                assertFalse(body.contains("SocketTimeoutException"))
                assertFalse(body.contains("connect timed out"))
                assertFalse(body.contains("Pregunta 1/10"))
            }
        } finally {
            System.err.flush()
            System.setErr(originalErr)
        }

        val stderr = captured.toString(StandardCharsets.UTF_8)
        assertContains(stderr, "CONNECT_TIMEOUT")
        assertContains(stderr, "SocketTimeoutException")
        assertFalse(stderr.contains("Authorization"))
        assertFalse(stderr.contains("Bearer"))
    }

    @Test
    fun usageMonitorAssignsDifferentWorkUnitForReplayInSameSession() {
        val usageFile = usageFile()
        val monitor = FileAiUsageMonitor(
            usageFile = usageFile,
            ratesByModel = mapOf("model-terra" to ModelRate("USD", "2.00".toBigDecimal(), "8.00".toBigDecimal())),
        )

        val prepare: (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError> = { plan ->
            val context = AiUsageContextHolder.current()
            monitor.recordCall(
                AiUsageCallEvent(
                    application = context?.application ?: "unknown-app",
                    operation = AiUsageOperation.COVERAGE,
                    model = "model-terra",
                    durationMillis = 100,
                    result = AiUsageCallResult.SUCCESS,
                    workUnitId = context?.workUnitId,
                    inputTokens = 100,
                    outputTokens = 20,
                    totalTokens = 120,
                    usageKnown = true,
                ),
            )
            val generated = preparedWithQuestions(topicFromPlan(plan))
            Outcome.Success(
                PreparedQuiz(
                    topic = generated.topic,
                    route = generated.route,
                    questions = generated.questions,
                    preparationMetrics = PreparedQuizPreparationMetrics(
                        preparationDurationMillis = 200,
                        invalidatedPositions = 1,
                        replacedQuestions = 1,
                        replacementAttempts = 2,
                    ),
                ),
            )
        }

        withServer(prepare = prepare, turn = turn, usageMonitor = monitor) { baseUrl, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val sessionId = extractSessionId(start.body())

            var finalBody = start.body()
            PreparedQuiz.correctOptionSequence.forEach { option ->
                finalBody = postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to option.toString())).body()
            }
            assertContains(finalBody, "Puntuación final 10/10")
            assertEquals(400, postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to "0")).statusCode())

            val replay = postForm("$baseUrl/games/$sessionId/navigation", mapOf("selection" to "1"))
            assertEquals(200, replay.statusCode())
            assertContains(replay.body(), "Pregunta 1/10")
        }

        val lines = Files.readAllLines(usageFile)
        val workUnits = lines.mapNotNull { Regex("\"workUnitId\":\"([^\"]+)\"").find(it)?.groupValues?.get(1) }.toSet()
        assertEquals(0, turnCalls.get())
        assertEquals(2, lines.count { it.contains("\"operation\":\"coverage\"") })
        assertEquals(0, lines.count { it.contains("\"operation\":\"luna\"") })
        assertEquals(2, lines.count { it.contains("\"metricName\":\"quiz10_preparation\"") })
        assertEquals(2, workUnits.size)
        assertEquals(1, lines.count { it.contains("quiz10_game_completed") })
        assertEquals(2, lines.count { it.contains("quiz10_game_started") })
    }

    @Test
    fun standardWebGameRegistersPreparationButNoLunaCalls() {
        val usageFile = usageFile()
        val monitor = FileAiUsageMonitor(
            usageFile = usageFile,
            ratesByModel = mapOf(
                "model-terra" to ModelRate("USD", "2.00".toBigDecimal(), "8.00".toBigDecimal()),
                "model-luna" to ModelRate("USD", "0.30".toBigDecimal(), "1.20".toBigDecimal()),
            ),
        )

        val prepare: (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError> = {
            val context = AiUsageContextHolder.current()
            monitor.recordCall(
                AiUsageCallEvent(
                    application = context?.application ?: "unknown-app",
                    operation = AiUsageOperation.COVERAGE,
                    model = "model-terra",
                    durationMillis = 100,
                    result = AiUsageCallResult.SUCCESS,
                    workUnitId = context?.workUnitId,
                    inputTokens = 120,
                    outputTokens = 30,
                    totalTokens = 150,
                    usageKnown = true,
                ),
            )
            Outcome.Success(preparedWithQuestions("Historia"))
        }

        withServer(prepare = prepare, turn = turn, usageMonitor = monitor) { baseUrl, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val sessionId = extractSessionId(start.body())

            PreparedQuiz.correctOptionSequence.forEach { option ->
                postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to option.toString()))
            }
        }

        val lines = Files.readAllLines(usageFile)
        assertEquals(0, turnCalls.get())
        assertTrue(lines.any { it.contains("\"operation\":\"coverage\"") })
        assertTrue(lines.none { it.contains("\"operation\":\"luna\"") })
    }

    @Test
    fun failedPreparationKeepsItsCallsAndAuditsUnderTheStartedWorkUnit() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(file, mapOf("model-terra" to ModelRate("USD", "1000000".toBigDecimal(), "0".toBigDecimal())))
        val prepare: (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError> = {
            val id = AiUsageContextHolder.current()?.workUnitId
            monitor.recordCall(AiUsageCallEvent("quiz10-web", AiUsageOperation.COVERAGE, "model-terra", 5,
                AiUsageCallResult.ERROR, id, 2, 0, 2, true))
            monitor.recordAudit(dev.magullodev.aiapps.core.ai.AiUsageAuditEvent("quiz10-web", "review", "initial_review",
                dev.magullodev.aiapps.core.ai.AiUsageAuditResult.REJECTED, id, 1, reason = "invalid row"))
            Outcome.Failure(QuizPreparationError.InvalidCoverageRouteSize(8))
        }
        withServer(prepare, usageMonitor = monitor) { baseUrl, _, _ ->
            assertEquals(500, postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection)).statusCode())
        }
        val lines = Files.readAllLines(file)
        val workUnits = lines.mapNotNull { Regex("\"workUnitId\":\"([^\"]+)\"").find(it)?.groupValues?.get(1) }.toSet()
        assertEquals(1, workUnits.size)
        assertEquals(1, lines.count { it.contains("\"type\":\"ai_call\"") })
        assertEquals(1, lines.count { it.contains("\"type\":\"audit\"") })
        assertTrue(lines.any { it.contains("quiz10_game_started") })
        assertTrue(lines.any { it.contains("quiz10_game_preparation_failed") })
    }

    @Test
    fun failedFirstTurnKeepsPreparationMetricAndDevelopmentUsage() {
        val file = usageFile()
        val monitor = FileAiUsageMonitor(file, mapOf("model" to ModelRate("USD", "1000000".toBigDecimal(), "0".toBigDecimal())))
        val prepare: (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError> = { plan ->
            val id = AiUsageContextHolder.current()?.workUnitId
            monitor.recordCall(AiUsageCallEvent("quiz10-web", AiUsageOperation.COVERAGE, "model", 1,
                AiUsageCallResult.SUCCESS, id, 2, 0, 2, true))
            val quiz = prepared(topicFromPlan(plan))
            Outcome.Success(PreparedQuiz(quiz.topic, quiz.route,
                preparationMetrics = PreparedQuizPreparationMetrics(1, 1, 0, 0)))
        }
        withServer(prepare, turn, monitor) { baseUrl, _, _ ->
            assertEquals(500, postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection)).statusCode())
        }
        val lines = Files.readAllLines(file)
        val workUnits = lines.mapNotNull { Regex("\"workUnitId\":\"([^\"]+)\"").find(it)?.groupValues?.get(1) }.toSet()
        assertEquals(1, workUnits.size)
        assertEquals(1, lines.count { it.contains("\"operation\":\"coverage\"") })
        assertEquals(1, lines.count { it.contains("\"operation\":\"luna\"") })
        assertTrue(lines.any { it.contains("quiz10_game_prepared") })
        assertTrue(lines.any { it.contains("quiz10_preparation") && it.contains("\"invalidated_positions\":1") })
        assertTrue(lines.any { it.contains("quiz10_game_execution_failed") })
    }

    private fun <T> withServer(
        prepare: (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError>,
        usageMonitor: AiUsageMonitor = AiUsageMonitor.NOOP,
        block: (baseUrl: String) -> T,
    ): T {
        Quiz10WebServer(
            prepareQuiz = prepare,
            usageMonitor = usageMonitor,
            port = 0,
        ).use { server ->
            val port = server.start()
            return block("http://127.0.0.1:$port")
        }
    }

    private fun prepareFailure(error: QuizPreparationError, onCall: () -> Unit = {}): (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError> = { _ ->
        onCall()
        Outcome.Failure(error)
    }

    private fun prepareSuccess(onCall: () -> Unit = {}): (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError> = { plan ->
        onCall()
        Outcome.Success(prepared(topicFromPlan(plan)))
    }

    private fun topicFromPlan(plan: StandardCoveragePlan): String {
        val labels = plan.positions.map { it.area.label }.distinct()
        return if (labels.size == 1) labels.single() else "Aleatorio"
    }

    private fun prepared(topic: String): PreparedQuiz {
        val route = CoverageRoute.of(List(10) { index ->
            CoverageRouteItem(
                difficulty = when (index) {
                    in 0..3 -> CoverageDifficulty.EASY
                    in 4..6 -> CoverageDifficulty.MODERATE
                    in 7..8 -> CoverageDifficulty.HARD
                    else -> CoverageDifficulty.VERY_HARD
                },
                area = "Area $index",
                group = "Group",
                referent = "Ref $index",
                knowledge = "Know",
                answer = "Ans",
            )
        })
        return PreparedQuiz(topic = topic, route = route, questions = route.items.map { item ->
            PreparedQuizQuestion("Question ${item.referent}", item.answer,
                listOf("Option A ${item.referent}", "Option B ${item.referent}", "Option C ${item.referent}"))
        })
    }

    private fun preparedWithQuestions(topic: String): PreparedQuiz {
        val route = CoverageRoute.of(List(10) { index ->
            CoverageRouteItem(
                difficulty = when (index) {
                    in 0..3 -> CoverageDifficulty.EASY
                    in 4..6 -> CoverageDifficulty.MODERATE
                    in 7..8 -> CoverageDifficulty.HARD
                    else -> CoverageDifficulty.VERY_HARD
                },
                area = "Area $index",
                group = "Group",
                referent = "Ref $index",
                knowledge = "Know",
                answer = "Ans",
            )
        })
        val questions = List(10) { index ->
            PreparedQuizQuestion(
                question = "Question $index",
                answer = "Ans",
                distractors = listOf("D1-$index", "D2-$index", "D3-$index"),
            )
        }
        return PreparedQuiz(topic = topic, route = route, questions = questions)
    }

    private fun extractSessionId(html: String): String {
        val regex = Regex("/games/([0-9a-fA-F-]+)/answer")
        return regex.find(html)?.groupValues?.get(1)
            ?: error("Session id not found in html")
    }

    private fun get(url: String): HttpResponse<String> {
        val request = HttpRequest.newBuilder(URI(url)).GET().build()
        return client.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8))
    }

    private fun postForm(url: String, form: Map<String, String>): HttpResponse<String> {
        val body = form.entries.joinToString("&") { (k, v) -> "${encode(k)}=${encode(v)}" }
        val request = HttpRequest.newBuilder(URI(url))
            .header("Content-Type", "application/x-www-form-urlencoded")
            .POST(HttpRequest.BodyPublishers.ofString(body, StandardCharsets.UTF_8))
            .build()
        return client.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8))
    }

    private fun encode(value: String): String = java.net.URLEncoder.encode(value, StandardCharsets.UTF_8)

    private fun ByteArrayOutputStream.printStream(): java.io.PrintStream = java.io.PrintStream(this, true, StandardCharsets.UTF_8)

    private fun usageFile(): Path {
        val root = Path.of("build", "tmp", "quiz10-web-no-luna-tests")
        Files.createDirectories(root)
        return Files.createTempFile(root, "usage-", ".jsonl")
    }
}
