package dev.magullodev.quiz10.apps.quiz10.web

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageDifficulty
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRoute
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRouteItem
import dev.magullodev.quiz10.systems.quiz10.preparation.PreparedQuiz
import dev.magullodev.quiz10.systems.quiz10.preparation.QuizPreparationError
import dev.magullodev.quiz10.systems.quiz10.question.QuizQuestion
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.charset.StandardCharsets
import java.util.concurrent.atomic.AtomicInteger
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals

class Quiz10WebServerTest {
    private val client = HttpClient.newHttpClient()

    @Test
    fun getRootShowsInitialForm() {
        withServer(prepareSuccess()) { baseUrl, _ ->
            val response = get("$baseUrl/")

            assertEquals(200, response.statusCode())
            assertContains(response.body(), "Empezar Quiz10")
        }
    }

    @Test
    fun createGameShowsFirstQuestionOnlyAfterPreparation() {
        val calls = AtomicInteger(0)
        withServer(prepareSuccess { calls.incrementAndGet() }) { baseUrl, _ ->
            val response = postForm("$baseUrl/games", mapOf("name" to "Ada", "topic" to "Historia"))

            assertEquals(1, calls.get())
            assertEquals(200, response.statusCode())
            assertContains(response.body(), "Pregunta 1/10")
        }
    }

    @Test
    fun fullTenAnswerRunShowsFinalAndUpdatesProgressWithStar() {
        withServer(prepareSuccess()) { baseUrl, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "topic" to "Historia"))
            val id = extractSessionId(start.body())

            var lastBody = start.body()
            PreparedQuiz.correctOptionSequence.forEach { option ->
                val answer = postForm("$baseUrl/games/$id/answer", mapOf("option" to option.toString()))
                assertEquals(200, answer.statusCode())
                lastBody = answer.body()
            }

            assertContains(lastBody, "Puntuación final 10/10")
            assertContains(lastBody, "Aciertos acumulados: 10")
            assertContains(lastBody, "Estrellas: ⭐ 1")
        }
    }

    @Test
    fun answerEndpointDoesNotPrepareAgainDuringQuestionLoop() {
        val prepareCalls = AtomicInteger(0)
        withServer(prepareSuccess { prepareCalls.incrementAndGet() }) { baseUrl, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "topic" to "Historia"))
            val id = extractSessionId(start.body())
            assertEquals(1, prepareCalls.get())

            repeat(9) {
                val answer = postForm("$baseUrl/games/$id/answer", mapOf("option" to PreparedQuiz.correctOptionSequence[it].toString()))
                assertEquals(200, answer.statusCode())
            }

            assertEquals(1, prepareCalls.get())
        }
    }

    @Test
    fun replaySameTopicKeepsProgress() {
        withServer(prepareSuccess()) { baseUrl, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "topic" to "Historia"))
            val id = extractSessionId(start.body())
            PreparedQuiz.correctOptionSequence.forEach { option -> postForm("$baseUrl/games/$id/answer", mapOf("option" to option.toString())) }

            val replay = postForm("$baseUrl/games/$id/navigation", mapOf("selection" to "1"))
            assertContains(replay.body(), "Pregunta 1/10")

            var final = replay.body()
            PreparedQuiz.correctOptionSequence.forEach { option ->
                final = postForm("$baseUrl/games/$id/answer", mapOf("option" to option.toString())).body()
            }

            assertContains(final, "Aciertos acumulados: 20")
            assertContains(final, "Estrellas: ⭐ 2")
        }
    }

    @Test
    fun chooseAnotherTopicKeepsProgress() {
        withServer(prepareSuccess()) { baseUrl, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "topic" to "Historia"))
            val id = extractSessionId(start.body())
            PreparedQuiz.correctOptionSequence.forEach { option -> postForm("$baseUrl/games/$id/answer", mapOf("option" to option.toString())) }

            val choose = postForm("$baseUrl/games/$id/navigation", mapOf("selection" to "3"))
            assertContains(choose.body(), "Elegir otro tema")

            val changed = postForm("$baseUrl/games/$id/topic", mapOf("topic" to "Ciencia"))
            assertContains(changed.body(), "Tema:</strong> Ciencia")

            var final = changed.body()
            PreparedQuiz.correctOptionSequence.forEach { option ->
                final = postForm("$baseUrl/games/$id/answer", mapOf("option" to option.toString())).body()
            }

            assertContains(final, "Aciertos acumulados: 20")
            assertContains(final, "1. 🔂 Otro Quiz10 de Ciencia")
        }
    }

    @Test
    fun reviewFailedAnswersDoesNotChangeProgress() {
        withServer(prepareSuccess()) { baseUrl, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "topic" to "Historia"))
            val id = extractSessionId(start.body())

            var finalBody = ""
            PreparedQuiz.correctOptionSequence.forEachIndexed { idx, option ->
                val selected = if (idx == 0) (option + 1) % 4 else option
                finalBody = postForm("$baseUrl/games/$id/answer", mapOf("option" to selected.toString())).body()
            }
            assertContains(finalBody, "Aciertos acumulados: 9")

            val review = postForm("$baseUrl/games/$id/navigation", mapOf("selection" to "4"))
            assertContains(review.body(), "Repaso de respuestas fallidas")
            assertContains(review.body(), "Pregunta 1")

            val panel = get("$baseUrl/games/$id/panel")
            assertContains(panel.body(), "Aciertos acumulados: 9")
            assertContains(panel.body(), "Estrellas: ⭐ 0")
        }
    }

    @Test
    fun missingSessionReturns404() {
        withServer(prepareSuccess()) { baseUrl, _ ->
            val response = postForm("$baseUrl/games/missing/answer", mapOf("option" to "0"))

            assertEquals(404, response.statusCode())
            assertContains(response.body(), "Sesión no encontrada")
        }
    }

    @Test
    fun invalidInputReturns400() {
        withServer(prepareSuccess()) { baseUrl, _ ->
            val response = postForm("$baseUrl/games", mapOf("name" to "", "topic" to ""))

            assertEquals(400, response.statusCode())
            assertContains(response.body(), "Solicitud inválida")
        }
    }

    private fun withServer(
        prepare: (String) -> Outcome<PreparedQuiz, QuizPreparationError>,
        block: (baseUrl: String, prepare: (String) -> Outcome<PreparedQuiz, QuizPreparationError>) -> Unit,
    ) {
        Quiz10WebServer(prepareQuiz = prepare, port = 0).use { server ->
            val port = server.start()
            block("http://127.0.0.1:$port", prepare)
        }
    }

    private fun prepareSuccess(onCall: () -> Unit = {}): (String) -> Outcome<PreparedQuiz, QuizPreparationError> = { topic ->
        onCall()
        Outcome.Success(prepared(topic))
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
        val questions = List(10) { index ->
            QuizQuestion(
                text = "Question $index",
                options = listOf("Option 0", "Option 1", "Option 2", "Option 3"),
                feedbackByOption = listOf("F0", "F1", "F2", "F3"),
                correctOptionIndex = PreparedQuiz.correctOptionSequence[index],
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
}
