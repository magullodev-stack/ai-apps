package dev.magullodev.quiz10.apps.quiz10.web

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageDifficulty
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRoute
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRouteItem
import dev.magullodev.quiz10.systems.quiz10.interaction.Quiz10InteractionContext
import dev.magullodev.quiz10.systems.quiz10.interaction.Quiz10InteractionError
import dev.magullodev.quiz10.systems.quiz10.interaction.Quiz10InteractionMessage
import dev.magullodev.quiz10.systems.quiz10.interaction.Quiz10InteractionEvent
import dev.magullodev.quiz10.systems.quiz10.preparation.PreparedQuiz
import dev.magullodev.quiz10.systems.quiz10.preparation.QuizPreparationError
import dev.magullodev.quiz10.systems.quiz10.preparation.luna.QuizTurnGenerationError
import dev.magullodev.quiz10.systems.quiz10.question.QuizQuestion
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.charset.StandardCharsets
import java.util.concurrent.CountDownLatch
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.system.measureTimeMillis
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class Quiz10WebServerTest {
    private val client = HttpClient.newHttpClient()

    private class InteractionProbe(
        private val delayMs: Long = 0,
        private val fixedResult: Outcome<Quiz10InteractionMessage, Quiz10InteractionError> =
            Outcome.Success(Quiz10InteractionMessage("Hola")),
        private val enteredLatch: CountDownLatch? = null,
        private val releaseLatch: CountDownLatch? = null,
    ) {
        val contexts = CopyOnWriteArrayList<Quiz10InteractionContext>()

        fun present(context: Quiz10InteractionContext): Outcome<Quiz10InteractionMessage, Quiz10InteractionError> {
            contexts += context

            enteredLatch?.countDown()

            if (releaseLatch != null) {
                if (!releaseLatch.await(10, TimeUnit.SECONDS)) {
                    error("Release latch timeout")
                }
            }

            if (delayMs > 0) Thread.sleep(delayMs)
            return fixedResult
        }
    }

    @Test
    fun getRootShowsInitialForm() {
        withServer(prepareSuccess()) { baseUrl, _, _, _ ->
            val response = get("$baseUrl/")

            assertEquals(200, response.statusCode())
            assertContains(response.body(), "Empezar Quiz10")
        }
    }

    @Test
    fun createGameShowsFirstQuestionOnlyAfterPreparationAndWithoutPresenterCall() {
        val coverageCalls = AtomicInteger(0)
        val turnCalls = AtomicInteger(0)
        val interaction = InteractionProbe()
        withServer(
            prepareSuccess { coverageCalls.incrementAndGet() },
            turnSuccess { _, _ -> turnCalls.incrementAndGet() },
            interaction,
        ) { baseUrl, _, _, probe ->
            val response = postForm("$baseUrl/games", mapOf("name" to "Ada", "topic" to "Historia"))

            assertEquals(1, coverageCalls.get())
            assertEquals(1, turnCalls.get())
            assertEquals(200, response.statusCode())
            assertContains(response.body(), "Pregunta 1/10")
            assertTrue(probe.contexts.isEmpty())
        }
    }

    @Test
    fun answerEndpointDoesNotPrepareAgainAndDoesNotInvokePresenter() {
        val prepareCalls = AtomicInteger(0)
        val turnCalls = AtomicInteger(0)
        val interaction = InteractionProbe()
        withServer(
            prepareSuccess { prepareCalls.incrementAndGet() },
            turnSuccess { _, _ -> turnCalls.incrementAndGet() },
            interaction,
        ) { baseUrl, _, _, probe ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "topic" to "Historia"))
            val id = extractSessionId(start.body())
            assertEquals(1, prepareCalls.get())
            assertEquals(1, turnCalls.get())

            repeat(9) {
                val answer = postForm("$baseUrl/games/$id/answer", mapOf("option" to PreparedQuiz.correctOptionSequence[it].toString()))
                assertEquals(200, answer.statusCode())
            }

            assertEquals(1, prepareCalls.get())
            assertEquals(10, turnCalls.get())
            assertTrue(probe.contexts.isEmpty())
        }
    }

    @Test
    fun onlyInteractionEndpointInvokesPresenter() {
        val interaction = InteractionProbe()
        withServer(prepareSuccess(), interactionProbe = interaction) { baseUrl, _, _, probe ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "topic" to "Historia"))
            val id = extractSessionId(start.body())
            val revision = extractInteractionRevision(start.body())

            val interactionResponse = get("$baseUrl/games/$id/interaction?revision=$revision")
            assertEquals(200, interactionResponse.statusCode())
            assertEquals(1, probe.contexts.size)

            postForm("$baseUrl/games/$id/answer", mapOf("option" to "0"))
            postForm("$baseUrl/games/$id/answer", mapOf("option" to "1"))
            assertEquals(1, probe.contexts.size)
        }
    }

    @Test
    fun interactionContextsAreWelcomeAfterAnswerAndFinish() {
        val interaction = InteractionProbe()
        withServer(prepareSuccess(), interactionProbe = interaction) { baseUrl, _, _, probe ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "topic" to "Historia"))
            val id = extractSessionId(start.body())

            val welcomeRevision = extractInteractionRevision(start.body())
            assertEquals(200, get("$baseUrl/games/$id/interaction?revision=$welcomeRevision").statusCode())
            val welcome = probe.contexts.last()
            assertEquals(Quiz10InteractionEvent.WELCOME, welcome.event)
            assertEquals("Ada", welcome.playerName)
            assertEquals("Historia", welcome.topic)
            assertEquals(0, welcome.answeredQuestions)
            assertEquals(0, welcome.correctAnswers)
            assertEquals(0, welcome.stars)
            assertEquals(null, welcome.lastAnswerCorrect)
            assertFalse(welcome.starEarned)

            val firstAnswer = postForm("$baseUrl/games/$id/answer", mapOf("option" to "0"))
            val afterRevision = extractInteractionRevision(firstAnswer.body())
            assertEquals(200, get("$baseUrl/games/$id/interaction?revision=$afterRevision").statusCode())
            val afterAnswer = probe.contexts.last()
            assertEquals(Quiz10InteractionEvent.AFTER_ANSWER, afterAnswer.event)
            assertEquals(1, afterAnswer.answeredQuestions)
            assertEquals(1, afterAnswer.correctAnswers)
            assertEquals(true, afterAnswer.lastAnswerCorrect)
            assertFalse(afterAnswer.starEarned)

            var finalBody = firstAnswer.body()
            for (index in 1 until 10) {
                finalBody = postForm(
                    "$baseUrl/games/$id/answer",
                    mapOf("option" to PreparedQuiz.correctOptionSequence[index].toString()),
                ).body()
            }
            val finishRevision = extractInteractionRevision(finalBody)
            assertEquals(200, get("$baseUrl/games/$id/interaction?revision=$finishRevision").statusCode())
            val finish = probe.contexts.last()
            assertEquals(Quiz10InteractionEvent.FINISH, finish.event)
            assertEquals(10, finish.answeredQuestions)
            assertEquals(10, finish.correctAnswers)
            assertEquals(1, finish.stars)
            assertTrue(finish.starEarned)
        }
    }

    @Test
    fun starEarnedIsTrueOnlyOnTenOutOfTen() {
        val interaction = InteractionProbe()
        withServer(prepareSuccess(), interactionProbe = interaction) { baseUrl, _, _, probe ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "topic" to "Historia"))
            val id = extractSessionId(start.body())

            var finalBody = ""
            PreparedQuiz.correctOptionSequence.forEachIndexed { index, option ->
                val selected = if (index == 0) (option + 1) % 4 else option
                finalBody = postForm("$baseUrl/games/$id/answer", mapOf("option" to selected.toString())).body()
            }

            val finishRevision = extractInteractionRevision(finalBody)
            assertEquals(200, get("$baseUrl/games/$id/interaction?revision=$finishRevision").statusCode())
            val finish = probe.contexts.last()
            assertEquals(Quiz10InteractionEvent.FINISH, finish.event)
            assertEquals(9, finish.correctAnswers)
            assertFalse(finish.starEarned)
        }
    }

    @Test
    fun obsoleteRevisionDoesNotUseNewState() {
        val interaction = InteractionProbe()
        withServer(prepareSuccess(), interactionProbe = interaction) { baseUrl, _, _, probe ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "topic" to "Historia"))
            val id = extractSessionId(start.body())
            val firstRevision = extractInteractionRevision(start.body())

            postForm("$baseUrl/games/$id/answer", mapOf("option" to "0"))

            val obsolete = get("$baseUrl/games/$id/interaction?revision=$firstRevision")
            assertEquals(409, obsolete.statusCode())
            assertTrue(probe.contexts.isEmpty())
        }
    }

    @Test
    fun missingSessionForInteractionReturns404() {
        withServer(prepareSuccess()) { baseUrl, _, _, _ ->
            val response = get("$baseUrl/games/missing/interaction?revision=1")

            assertEquals(404, response.statusCode())
            assertContains(response.body(), "Sesión no encontrada")
        }
    }

    @Test
    fun failedInteractionDoesNotBlockGameAndDoesNotModifyFlowOrProgress() {
        val interaction = InteractionProbe(
            fixedResult = Outcome.Failure(Quiz10InteractionError.InvalidGeneratedMessage),
        )
        withServer(prepareSuccess(), interactionProbe = interaction) { baseUrl, _, _, probe ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "topic" to "Historia"))
            val id = extractSessionId(start.body())
            val firstRevision = extractInteractionRevision(start.body())

            val failedInteraction = get("$baseUrl/games/$id/interaction?revision=$firstRevision")
            assertEquals(503, failedInteraction.statusCode())
            assertEquals(1, probe.contexts.size)

            val answer = postForm("$baseUrl/games/$id/answer", mapOf("option" to "0"))
            assertEquals(200, answer.statusCode())
            assertContains(answer.body(), "Pregunta 2/10")

            var finalBody = answer.body()
            for (index in 1 until 10) {
                finalBody = postForm(
                    "$baseUrl/games/$id/answer",
                    mapOf("option" to PreparedQuiz.correctOptionSequence[index].toString()),
                ).body()
            }

            assertContains(finalBody, "Puntuación final 10/10")
            assertContains(finalBody, "Aciertos acumulados: 10")
            assertContains(finalBody, "Estrellas: ⭐ 1")
        }
    }

    @Test
    fun slowInteractionDoesNotBlockAnswerProcessing() {
        val enteredPresenter = CountDownLatch(1)
        val releasePresenter = CountDownLatch(1)
        val interaction = InteractionProbe(
            enteredLatch = enteredPresenter,
            releaseLatch = releasePresenter,
        )
        withServer(prepareSuccess(), interactionProbe = interaction) { baseUrl, _, _, probe ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "topic" to "Historia"))
            val id = extractSessionId(start.body())
            val revision = extractInteractionRevision(start.body())

            var interactionResponse: HttpResponse<String>? = null
            val interactionThread = Thread {
                interactionResponse = get("$baseUrl/games/$id/interaction?revision=$revision")
            }
            interactionThread.start()

            if (!enteredPresenter.await(5, TimeUnit.SECONDS)) {
                error("Presenter did not enter within timeout")
            }

            val answerElapsed = measureTimeMillis {
                val answer = postForm("$baseUrl/games/$id/answer", mapOf("option" to "0"))
                assertEquals(200, answer.statusCode())
                assertContains(answer.body(), "Pregunta 2/10")
            }

            assertTrue(answerElapsed < 400, "POST /answer tardó demasiado: ${answerElapsed}ms")

            releasePresenter.countDown()
            interactionThread.join(5000)

            assertEquals(200, interactionResponse?.statusCode())
            assertEquals(1, probe.contexts.size)
        }
    }

    @Test
    fun replaySameTopicKeepsProgress() {
        withServer(prepareSuccess()) { baseUrl, _, _, _ ->
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
        withServer(prepareSuccess()) { baseUrl, _, _, _ ->
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
        withServer(prepareSuccess()) { baseUrl, _, _, _ ->
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
        withServer(prepareSuccess()) { baseUrl, _, _, _ ->
            val response = postForm("$baseUrl/games/missing/answer", mapOf("option" to "0"))

            assertEquals(404, response.statusCode())
            assertContains(response.body(), "Sesión no encontrada")
        }
    }

    @Test
    fun invalidInputReturns400() {
        withServer(prepareSuccess()) { baseUrl, _, _, _ ->
            val response = postForm("$baseUrl/games", mapOf("name" to "", "topic" to ""))

            assertEquals(400, response.statusCode())
            assertContains(response.body(), "Solicitud inválida")
        }
    }

    private fun withServer(
        prepare: (String) -> Outcome<PreparedQuiz, QuizPreparationError>,
        turn: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError> = turnSuccess(),
        interactionProbe: InteractionProbe = InteractionProbe(),
        block: (
            baseUrl: String,
            prepare: (String) -> Outcome<PreparedQuiz, QuizPreparationError>,
            turn: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError>,
            interactionProbe: InteractionProbe,
        ) -> Unit,
    ) {
        Quiz10WebServer(
            prepareQuiz = prepare,
            generateTurn = turn,
            presentInteraction = interactionProbe::present,
            port = 0,
        ).use { server ->
            val port = server.start()
            block("http://127.0.0.1:$port", prepare, turn, interactionProbe)
        }
    }

    private fun prepareSuccess(onCall: () -> Unit = {}): (String) -> Outcome<PreparedQuiz, QuizPreparationError> = { topic ->
        onCall()
        Outcome.Success(prepared(topic))
    }

    private fun turnSuccess(
        onCall: (CoverageRouteItem, Int) -> Unit = { _, _ -> },
    ): (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError> = { item, correctIndex ->
        onCall(item, correctIndex)
        val options = mutableListOf(
            "Option A ${item.referent}",
            "Option B ${item.referent}",
            "Option C ${item.referent}",
        )
        val feedback = mutableListOf(
            "FA ${item.referent}",
            "FB ${item.referent}",
            "FC ${item.referent}",
        )
        options.add(correctIndex, item.answer)
        feedback.add(correctIndex, "Correct ${item.knowledge}")
        Outcome.Success(
            QuizQuestion(
                text = "Question ${item.referent}",
                options = options,
                feedbackByOption = feedback,
                correctOptionIndex = correctIndex,
            ),
        )
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
        return PreparedQuiz(topic = topic, route = route)
    }

    private fun extractSessionId(html: String): String {
        val regex = Regex("/games/([0-9a-fA-F-]+)/answer")
        return regex.find(html)?.groupValues?.get(1)
            ?: error("Session id not found in html")
    }

    private fun extractInteractionRevision(html: String): Long {
        val regex = Regex("/interaction\\?revision=(\\d+)")
        return regex.find(html)?.groupValues?.get(1)?.toLongOrNull()
            ?: error("Interaction revision not found in html")
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
