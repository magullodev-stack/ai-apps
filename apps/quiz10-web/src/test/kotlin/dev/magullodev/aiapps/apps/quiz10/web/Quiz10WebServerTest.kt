package dev.magullodev.aiapps.apps.quiz10.web

import dev.magullodev.aiapps.core.ai.AiUsageCallEvent
import dev.magullodev.aiapps.core.ai.AiUsageCallResult
import dev.magullodev.aiapps.core.ai.AiUsageContextHolder
import dev.magullodev.aiapps.core.ai.AiUsageFilter
import dev.magullodev.aiapps.core.ai.AiUsageMonitor
import dev.magullodev.aiapps.core.ai.AiUsageOperation
import dev.magullodev.aiapps.core.ai.AiUsageQueryService
import dev.magullodev.aiapps.core.ai.AiUsageRecordRepository
import dev.magullodev.aiapps.core.ai.FileAiUsageMonitor
import dev.magullodev.aiapps.core.ai.ModelRate
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRouteItem
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlan
import dev.magullodev.aiapps.systems.games.quiz10.preparation.PreparedQuiz
import dev.magullodev.aiapps.systems.games.quiz10.preparation.PreparedQuizQuestion
import dev.magullodev.aiapps.systems.games.quiz10.preparation.QuizPreparationError
import dev.magullodev.aiapps.systems.games.quiz10.preparation.luna.QuizTurnGenerationError
import dev.magullodev.aiapps.systems.games.quiz10.question.QuizQuestion
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
    fun finishAndReplayKeepGameplayWithoutAutomaticComments() {
        withServer(prepareSuccess()) { baseUrl, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val sessionId = extractSessionId(start.body())

            var finalBody = ""
            PreparedQuiz.correctOptionSequence.forEach { option ->
                finalBody = postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to option.toString())).body()
            }

            assertContains(finalBody, "Puntuación final 10/10")
            assertContains(finalBody, "Aciertos acumulados: 10")
            assertFalse(finalBody.contains("Luna"))
            assertFalse(finalBody.contains("/interaction?"))

            val replay = postForm("$baseUrl/games/$sessionId/navigation", mapOf("selection" to "1"))
            assertEquals(200, replay.statusCode())
            assertContains(replay.body(), "Pregunta 1/10")
            assertFalse(replay.body().contains("Luna"))
            assertFalse(replay.body().contains("/interaction?"))
        }
    }

    @Test
    fun interactionEndpointIsNoLongerUsedByWebGame() {
        withServer(prepareSuccess()) { baseUrl, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val sessionId = extractSessionId(start.body())

            val interaction = get("$baseUrl/games/$sessionId/interaction?revision=1")
            assertEquals(404, interaction.statusCode())
            assertContains(interaction.body(), "Sesión no encontrada")
        }
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
        val turnCalls = AtomicInteger(0)

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

        val turn: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError> = { _, _ ->
            turnCalls.incrementAndGet()
            val context = AiUsageContextHolder.current()
            monitor.recordCall(
                AiUsageCallEvent(
                    application = context?.application ?: "unknown-app",
                    operation = AiUsageOperation.LUNA,
                    model = "model-luna",
                    durationMillis = 20,
                    result = AiUsageCallResult.SUCCESS,
                    workUnitId = context?.workUnitId,
                    inputTokens = 10,
                    outputTokens = 5,
                    totalTokens = 15,
                    usageKnown = true,
                ),
            )
            Outcome.Failure(QuizTurnGenerationError.InvalidGeneratedTurn)
        }

        withServer(prepare = prepare, turn = turn, usageMonitor = monitor) { baseUrl, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val sessionId = extractSessionId(start.body())

            PreparedQuiz.correctOptionSequence.forEach { option ->
                postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to option.toString()))
            }
        }

        val summary = AiUsageQueryService(AiUsageRecordRepository(usageFile)).summarize(
            AiUsageFilter(application = "quiz10-web"),
        )

        assertEquals(0, turnCalls.get())
        assertTrue(summary.byOperation["coverage"]?.calls ?: 0 >= 1)
        assertEquals(null, summary.byOperation["luna"])
    }

    private fun <T> withServer(
        prepare: (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError>,
        turn: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError> = turnFailure(),
        usageMonitor: AiUsageMonitor = AiUsageMonitor.NOOP,
        block: (baseUrl: String, prepare: (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError>, turn: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError>) -> T,
    ): T {
        Quiz10WebServer(
            prepareQuiz = prepare,
            generateTurn = turn,
            usageMonitor = usageMonitor,
            port = 0,
        ).use { server ->
            val port = server.start()
            return block("http://127.0.0.1:$port", prepare, turn)
        }
    }

    private fun prepareSuccess(): (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError> = { plan ->
        Outcome.Success(preparedWithQuestions(topicFromPlan(plan)))
    }

    private fun topicFromPlan(plan: StandardCoveragePlan): String {
        val labels = plan.positions.map { it.area.label }.distinct()
        return if (labels.size == 1) labels.single() else "Aleatorio"
    }

    private fun turnFailure(): (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError> = { _, _ ->
        Outcome.Failure(QuizTurnGenerationError.InvalidGeneratedTurn)
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

    private fun usageFile(): Path {
        val root = Path.of("build", "tmp", "quiz10-web-no-luna-tests")
        Files.createDirectories(root)
        return Files.createTempFile(root, "usage-", ".jsonl")
    }
}
