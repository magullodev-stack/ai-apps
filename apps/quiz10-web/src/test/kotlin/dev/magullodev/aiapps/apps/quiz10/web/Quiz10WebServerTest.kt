package dev.magullodev.aiapps.apps.quiz10.web

import dev.magullodev.aiapps.core.ai.AiUsageCallEvent
import dev.magullodev.aiapps.core.ai.AiUsageCallResult
import dev.magullodev.aiapps.core.ai.AiUsageContextHolder
import dev.magullodev.aiapps.core.ai.AiUsageMonitor
import dev.magullodev.aiapps.core.ai.AiUsageOperation
import dev.magullodev.aiapps.core.ai.AiUsageQueryService
import dev.magullodev.aiapps.core.ai.AiUsageRecordRepository
import dev.magullodev.aiapps.core.ai.FileAiUsageMonitor
import dev.magullodev.aiapps.core.ai.ModelRate
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.AiTransportFailureKind
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRouteItem
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlan
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.CoverageRouteGenerationError
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.CoverageRouteValidationError
import dev.magullodev.aiapps.systems.games.quiz10.interaction.Quiz10InteractionContext
import dev.magullodev.aiapps.systems.games.quiz10.interaction.Quiz10InteractionError
import dev.magullodev.aiapps.systems.games.quiz10.interaction.Quiz10InteractionMessage
import dev.magullodev.aiapps.systems.games.quiz10.interaction.Quiz10InteractionEvent
import dev.magullodev.aiapps.systems.games.quiz10.preparation.PreparedQuiz
import dev.magullodev.aiapps.systems.games.quiz10.preparation.QuizPreparationError
import dev.magullodev.aiapps.systems.games.quiz10.preparation.luna.QuizTurnGenerationError
import dev.magullodev.aiapps.systems.games.quiz10.question.QuizQuestion
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.io.ByteArrayOutputStream
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import java.util.concurrent.CountDownLatch
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.system.measureTimeMillis
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class Quiz10WebServerTest {
    private val client = HttpClient.newHttpClient()
    private val defaultSelection = "Historia"
    private val alternativeSelection = "Física"

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
            val response = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))

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
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
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
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
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
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
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
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
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
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
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
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
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
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
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
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
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
    fun replaySameTopicPreparationFailurePreservesFinishedGameAndAllowsRetry() {
        val prepareCalls = AtomicInteger(0)
        val prepare: (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError> = { plan ->
            when (prepareCalls.incrementAndGet()) {
                2 -> Outcome.Failure(QuizPreparationError.InvalidCoverageRouteSize(8))
                else -> Outcome.Success(prepared(topicFromPlan(plan)))
            }
        }

        withServer(prepare = prepare) { baseUrl, _, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val id = extractSessionId(start.body())
            var finished = ""
            PreparedQuiz.correctOptionSequence.forEach { option ->
                finished = postForm("$baseUrl/games/$id/answer", mapOf("option" to option.toString())).body()
            }

            val finishedRevision = extractInteractionRevision(finished)
            val failedReplay = postForm("$baseUrl/games/$id/navigation", mapOf("selection" to "1"))
            assertEquals(500, failedReplay.statusCode())
            assertContains(failedReplay.body(), "InvalidCoverageRouteSize")
            assertContains(failedReplay.body(), "/games/$id/panel")

            val panel = get("$baseUrl/games/$id/panel")
            assertEquals(200, panel.statusCode())
            assertContains(panel.body(), "Puntuación final 10/10")
            assertContains(panel.body(), "Aciertos acumulados: 10")
            assertContains(panel.body(), "1. 🔂 Otro Quiz10 de Historia")
            assertEquals(finishedRevision, extractInteractionRevision(panel.body()))

            val retry = postForm("$baseUrl/games/$id/navigation", mapOf("selection" to "1"))
            assertEquals(200, retry.statusCode())
            assertContains(retry.body(), "Pregunta 1/10")
            assertContains(retry.body(), "Tema:</strong> Historia")
        }
    }

    @Test
    fun replaySameTopicTurnFailurePreservesFinishedGameAndAllowsRetry() {
        val turnCalls = AtomicInteger(0)
        val successfulTurn = turnSuccess()
        val turn: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError> = { item, correctIndex ->
            if (turnCalls.incrementAndGet() == 11) {
                Outcome.Failure(QuizTurnGenerationError.GenerationFailed(AiError.TransportFailure))
            } else {
                successfulTurn(item, correctIndex)
            }
        }

        withServer(prepare = prepareSuccess(), turn = turn) { baseUrl, _, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val id = extractSessionId(start.body())
            var finished = ""
            PreparedQuiz.correctOptionSequence.forEach { option ->
                finished = postForm("$baseUrl/games/$id/answer", mapOf("option" to option.toString())).body()
            }

            val finishedRevision = extractInteractionRevision(finished)
            val failedReplay = postForm("$baseUrl/games/$id/navigation", mapOf("selection" to "1"))
            assertEquals(500, failedReplay.statusCode())
            assertContains(failedReplay.body(), "pregunta 1")
            assertContains(failedReplay.body(), "/games/$id/panel")

            val panel = get("$baseUrl/games/$id/panel")
            assertEquals(200, panel.statusCode())
            assertContains(panel.body(), "Aciertos acumulados: 10")
            assertContains(panel.body(), "1. 🔂 Otro Quiz10 de Historia")
            assertEquals(finishedRevision, extractInteractionRevision(panel.body()))

            val retry = postForm("$baseUrl/games/$id/navigation", mapOf("selection" to "1"))
            assertEquals(200, retry.statusCode())
            assertContains(retry.body(), "Pregunta 1/10")
            assertContains(retry.body(), "Tema:</strong> Historia")
        }
    }

    @Test
    fun chooseAnotherTopicKeepsProgress() {
        withServer(prepareSuccess()) { baseUrl, _, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val id = extractSessionId(start.body())
            PreparedQuiz.correctOptionSequence.forEach { option -> postForm("$baseUrl/games/$id/answer", mapOf("option" to option.toString())) }

            val choose = postForm("$baseUrl/games/$id/navigation", mapOf("selection" to "3"))
            assertContains(choose.body(), "Elegir modalidad o área")

            val changed = postForm("$baseUrl/games/$id/topic", mapOf("selection" to alternativeSelection))
            assertContains(changed.body(), "Tema:</strong> Física")

            var final = changed.body()
            PreparedQuiz.correctOptionSequence.forEach { option ->
                final = postForm("$baseUrl/games/$id/answer", mapOf("option" to option.toString())).body()
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

        withServer(prepare = prepare) { baseUrl, _, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val id = extractSessionId(start.body())
            var finished = ""
            PreparedQuiz.correctOptionSequence.forEach { option ->
                finished = postForm("$baseUrl/games/$id/answer", mapOf("option" to option.toString())).body()
            }

            val finishedRevision = extractInteractionRevision(finished)
            val choose = postForm("$baseUrl/games/$id/navigation", mapOf("selection" to "3"))
            assertEquals(200, choose.statusCode())
            assertContains(choose.body(), "Elegir modalidad o área")

            val failedChange = postForm("$baseUrl/games/$id/topic", mapOf("selection" to alternativeSelection))
            assertEquals(500, failedChange.statusCode())
            assertContains(failedChange.body(), "CoverageRouteGenerationFailed")
            assertContains(failedChange.body(), "/games/$id/panel")

            val panel = get("$baseUrl/games/$id/panel")
            assertEquals(200, panel.statusCode())
            assertContains(panel.body(), "Aciertos acumulados: 10")
            assertContains(panel.body(), "1. 🔂 Otro Quiz10 de Historia")
            assertEquals(finishedRevision, extractInteractionRevision(panel.body()))

            val chooseAgain = postForm("$baseUrl/games/$id/navigation", mapOf("selection" to "3"))
            assertEquals(200, chooseAgain.statusCode())
            val changed = postForm("$baseUrl/games/$id/topic", mapOf("selection" to alternativeSelection))
            assertEquals(200, changed.statusCode())
            assertContains(changed.body(), "Pregunta 1/10")
            assertContains(changed.body(), "Tema:</strong> Física")
        }
    }

    @Test
    fun chooseAnotherTopicTurnFailurePreservesFinishedGameAndAllowsRetry() {
        val turnCalls = AtomicInteger(0)
        val successfulTurn = turnSuccess()
        val turn: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError> = { item, correctIndex ->
            if (turnCalls.incrementAndGet() == 11) {
                Outcome.Failure(QuizTurnGenerationError.GenerationFailed(AiError.TransportFailure))
            } else {
                successfulTurn(item, correctIndex)
            }
        }

        withServer(prepare = prepareSuccess(), turn = turn) { baseUrl, _, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val id = extractSessionId(start.body())
            var finished = ""
            PreparedQuiz.correctOptionSequence.forEach { option ->
                finished = postForm("$baseUrl/games/$id/answer", mapOf("option" to option.toString())).body()
            }

            val finishedRevision = extractInteractionRevision(finished)
            val choose = postForm("$baseUrl/games/$id/navigation", mapOf("selection" to "3"))
            assertEquals(200, choose.statusCode())

            val failedChange = postForm("$baseUrl/games/$id/topic", mapOf("selection" to alternativeSelection))
            assertEquals(500, failedChange.statusCode())
            assertContains(failedChange.body(), "pregunta 1")
            assertContains(failedChange.body(), "/games/$id/panel")

            val panel = get("$baseUrl/games/$id/panel")
            assertEquals(200, panel.statusCode())
            assertContains(panel.body(), "Aciertos acumulados: 10")
            assertContains(panel.body(), "1. 🔂 Otro Quiz10 de Historia")
            assertEquals(finishedRevision, extractInteractionRevision(panel.body()))

            val chooseAgain = postForm("$baseUrl/games/$id/navigation", mapOf("selection" to "3"))
            assertEquals(200, chooseAgain.statusCode())
            val changed = postForm("$baseUrl/games/$id/topic", mapOf("selection" to alternativeSelection))
            assertEquals(200, changed.statusCode())
            assertContains(changed.body(), "Pregunta 1/10")
            assertContains(changed.body(), "Tema:</strong> Física")
        }
    }

    @Test
    fun reviewFailedAnswersDoesNotChangeProgress() {
        withServer(prepareSuccess()) { baseUrl, _, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
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
            val response = postForm("$baseUrl/games", mapOf("name" to "", "selection" to ""))

            assertEquals(400, response.statusCode())
            assertContains(response.body(), "Solicitud inválida")
        }
    }

    @Test
    fun coverageGenerationFailureShowsTypedCoverageMessage() {
        withServer(prepareFailure(QuizPreparationError.CoverageRouteGenerationFailed(CoverageRouteGenerationError.GenerationFailed(AiError.TransportFailure)))) { baseUrl, _, _, _ ->
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
        withServer(prepareFailure(QuizPreparationError.InvalidCoverageRouteSize(8))) { baseUrl, _, _, _ ->
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
        ) { baseUrl, _, _, _ ->
            val response = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))

            assertEquals(422, response.statusCode())
            val body = response.body()
            assertContains(body, "rechazada por validación semántica")
            assertContains(body, "repite referentes")
            assertFalse(body.contains("Authorization"))
        }
    }

    @Test
    fun turnGenerationFailureShowsQuestionNumber() {
        withServer(
            prepareSuccess(),
            turnFailure(QuizTurnGenerationError.GenerationFailed(AiError.TransportFailure), questionNumber = 1),
        ) { baseUrl, _, _, _ ->
            val response = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))

            assertEquals(500, response.statusCode())
            val body = response.body()
            assertContains(body, "pregunta 1")
            assertContains(body, "TurnGenerationFailed")
            assertFalse(body.contains("Authorization"))
        }
    }

    @Test
    fun happyPathStillReturnsTheQuestionNormally() {
        withServer(prepareSuccess(), turnSuccess()) { baseUrl, _, _, _ ->
            val response = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))

            assertEquals(200, response.statusCode())
            assertContains(response.body(), "Pregunta 1/10")
            assertFalse(response.body().contains("Authorization"))
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
            ) { baseUrl, _, _, _ ->
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
    fun usageMonitorIntegratesPreparationAndLunaEventsPerSession() {
        val usageFile = usageFile()
        val monitor = FileAiUsageMonitor(
            usageFile = usageFile,
            ratesByModel = mapOf(
                "model-terra" to ModelRate("USD", "2.00".toBigDecimal(), "8.00".toBigDecimal()),
                "model-luna" to ModelRate("USD", "0.30".toBigDecimal(), "1.20".toBigDecimal()),
            ),
        )
        val baseTurn = turnSuccess()

        val prepare: (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError> = { plan ->
            val context = AiUsageContextHolder.current()
            assertEquals("quiz10-web", context?.application)
            monitor.recordCall(
                AiUsageCallEvent(
                    application = context?.application ?: "unknown-app",
                    operation = AiUsageOperation.COVERAGE,
                    model = "model-terra",
                    durationMillis = 100,
                    result = AiUsageCallResult.SUCCESS,
                    workUnitId = context?.workUnitId,
                    inputTokens = 200,
                    outputTokens = 40,
                    totalTokens = 240,
                    usageKnown = true,
                ),
            )
            val generated = prepared(topicFromPlan(plan))
            Outcome.Success(
                PreparedQuiz(
                    topic = generated.topic,
                    route = generated.route,
                    questions = generated.questions,
                    preparationMetrics = dev.magullodev.aiapps.systems.games.quiz10.preparation.PreparedQuizPreparationMetrics(
                        preparationDurationMillis = 250,
                        invalidatedPositions = 2,
                        replacedQuestions = 2,
                        replacementAttempts = 3,
                    ),
                ),
            )
        }

        val turn: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError> = { item, correctIndex ->
            val context = AiUsageContextHolder.current()
            assertEquals("quiz10-web", context?.application)
            monitor.recordCall(
                AiUsageCallEvent(
                    application = context?.application ?: "unknown-app",
                    operation = AiUsageOperation.LUNA,
                    model = "model-luna",
                    durationMillis = 30,
                    result = AiUsageCallResult.SUCCESS,
                    workUnitId = context?.workUnitId,
                    inputTokens = 20,
                    outputTokens = 10,
                    totalTokens = 30,
                    usageKnown = true,
                ),
            )
            baseTurn(item, correctIndex)
        }

        val interaction = InteractionProbe(
            fixedResult = Outcome.Success(Quiz10InteractionMessage("mensaje")),
        )

        withServer(prepare = prepare, turn = turn, interactionProbe = interaction, usageMonitor = monitor) { baseUrl, _, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val sessionId = extractSessionId(start.body())

            val answer = postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to "0"))
            val revision = extractInteractionRevision(answer.body())
            val interactionResponse = get("$baseUrl/games/$sessionId/interaction?revision=$revision")
            assertEquals(200, interactionResponse.statusCode())

            val summary = AiUsageQueryService(AiUsageRecordRepository(usageFile)).summarize(
                dev.magullodev.aiapps.core.ai.AiUsageFilter(
                    application = "quiz10-web",
                ),
            )
            val distinctWorkUnits = (summary.calls + summary.metrics)
                .mapNotNull { it.workUnitId }
                .toSet()

            assertEquals(3, summary.calls.size)
            assertEquals(1, summary.byOperation["coverage"]?.calls)
            assertEquals(2, summary.byOperation["luna"]?.calls)
            assertEquals(1, summary.metrics.size)
            assertEquals("quiz10_preparation", summary.metrics.single().metricName)
            assertEquals(1, distinctWorkUnits.size)
            assertFalse(distinctWorkUnits.contains(sessionId))
            assertNotNull(summary.totalCostByCurrency["USD"])
        }
    }

    @Test
    fun usageMonitorAssignsDifferentWorkUnitForReplayInSameSession() {
        val usageFile = usageFile()
        val monitor = FileAiUsageMonitor(
            usageFile = usageFile,
            ratesByModel = mapOf(
                "model-terra" to ModelRate("USD", "2.00".toBigDecimal(), "8.00".toBigDecimal()),
                "model-luna" to ModelRate("USD", "0.30".toBigDecimal(), "1.20".toBigDecimal()),
            ),
        )
        val baseTurn = turnSuccess()

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
            val generated = prepared(topicFromPlan(plan))
            Outcome.Success(
                PreparedQuiz(
                    topic = generated.topic,
                    route = generated.route,
                    questions = generated.questions,
                    preparationMetrics = dev.magullodev.aiapps.systems.games.quiz10.preparation.PreparedQuizPreparationMetrics(
                        preparationDurationMillis = 200,
                        invalidatedPositions = 1,
                        replacedQuestions = 1,
                        replacementAttempts = 2,
                    ),
                ),
            )
        }

        val turn: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError> = { item, correctIndex ->
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
            baseTurn(item, correctIndex)
        }

        withServer(prepare = prepare, turn = turn, usageMonitor = monitor) { baseUrl, _, _, _ ->
            val start = postForm("$baseUrl/games", mapOf("name" to "Ada", "selection" to defaultSelection))
            val sessionId = extractSessionId(start.body())

            var finalBody = start.body()
            PreparedQuiz.correctOptionSequence.forEach { option ->
                finalBody = postForm("$baseUrl/games/$sessionId/answer", mapOf("option" to option.toString())).body()
            }
            assertContains(finalBody, "Puntuación final 10/10")

            val replay = postForm("$baseUrl/games/$sessionId/navigation", mapOf("selection" to "1"))
            assertEquals(200, replay.statusCode())
            assertContains(replay.body(), "Pregunta 1/10")

            val summary = AiUsageQueryService(AiUsageRecordRepository(usageFile)).summarize(
                dev.magullodev.aiapps.core.ai.AiUsageFilter(application = "quiz10-web"),
            )
            val workUnits = (summary.calls + summary.metrics).mapNotNull { it.workUnitId }.toSet()

            assertEquals(13, summary.calls.size)
            assertEquals(2, summary.metrics.size)
            assertEquals(2, workUnits.size)
            assertFalse(workUnits.contains(sessionId))
        }
    }

    private fun withServer(
        prepare: (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError>,
        turn: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError> = turnSuccess(),
        interactionProbe: InteractionProbe = InteractionProbe(),
        usageMonitor: AiUsageMonitor = AiUsageMonitor.NOOP,
        block: (
            baseUrl: String,
            prepare: (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError>,
            turn: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError>,
            interactionProbe: InteractionProbe,
        ) -> Unit,
    ) {
        Quiz10WebServer(
            prepareQuiz = prepare,
            generateTurn = turn,
            presentInteraction = interactionProbe::present,
            usageMonitor = usageMonitor,
            port = 0,
        ).use { server ->
            val port = server.start()
            block("http://127.0.0.1:$port", prepare, turn, interactionProbe)
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

    private fun turnFailure(
        error: QuizTurnGenerationError,
        questionNumber: Int = 1,
        onCall: (CoverageRouteItem, Int) -> Unit = { _, _ -> },
    ): (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError> = { item, correctIndex ->
        onCall(item, correctIndex)
        Outcome.Failure(error)
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

    private fun ByteArrayOutputStream.printStream(): java.io.PrintStream = java.io.PrintStream(this, true, StandardCharsets.UTF_8)

    private fun usageFile(): Path {
        val root = Path.of("build", "tmp", "quiz10-web-usage-tests")
        Files.createDirectories(root)
        return Files.createTempFile(root, "usage-", ".jsonl")
    }
}
