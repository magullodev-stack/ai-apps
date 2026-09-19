package dev.magullodev.aiapps.systems.games.quiz10.interaction

import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertIs

class Quiz10InteractionPresenterTest {
    private class ControlledGeneration(
        private val result: Outcome<StructuredGeneration, AiError>,
    ) {
        val requests = mutableListOf<StructuredGenerationRequest>()

        fun generate(request: StructuredGenerationRequest): Outcome<StructuredGeneration, AiError> {
            requests += request
            return result
        }
    }

    private val baseContext = Quiz10InteractionContext(
        event = Quiz10InteractionEvent.AFTER_ANSWER,
        playerName = "Ada",
        topic = "Historia",
        answeredQuestions = 3,
        correctAnswers = 2,
        totalQuestions = 10,
        stars = 1,
        lastAnswerCorrect = false,
        starEarned = false,
    )

    @Test
    fun requestUsesLunaProfileStrictMessageSchemaAndPromptContext() {
        val generation = ControlledGeneration(Outcome.Success(StructuredGeneration("{\"message\":\"Vamos muy bien.\"}", null)))
        val presenter = Quiz10InteractionPresenter(generation::generate)

        val result = presenter.present(baseContext)

        val message = assertIs<Outcome.Success<Quiz10InteractionMessage>>(result).value
        assertEquals("Vamos muy bien.", message.message)
        val request = generation.requests.single()
        assertEquals(AiProfile.LUNA, request.profile)
        assertEquals("quiz10_interaction_message", request.schemaName)

        val schema = Json.parseToJsonElement(request.schemaJson)
        val root = schema.jsonObject
        assertEquals(JsonPrimitive("object"), root["type"])
        assertEquals(JsonArray(listOf(JsonPrimitive("message"))), root["required"])
        assertEquals(JsonPrimitive(false), root["additionalProperties"])
        assertEquals(setOf("message"), root.getValue("properties").jsonObject.keys)

        assertContains(request.input, "evento: AFTER_ANSWER")
        assertContains(request.input, "jugador: Ada")
        assertContains(request.input, "tema: Historia")
        assertContains(request.input, "respondidas: 3/10")
        assertContains(request.input, "aciertos: 2")
        assertContains(request.input, "fallos: 1")
        assertContains(request.input, "estrellas: 1")
        assertContains(request.input, "último acierto: false")
        assertContains(request.input, "estrella ganada en esta partida: false")
        assertContains(request.input, "Prohibido:")
        assertContains(request.input, "aportar conocimiento factual del tema")
        assertContains(request.input, "explicar respuestas")
        assertContains(request.input, "dar pistas")
    }

    @Test
    fun generationFailurePreservesAiCause() {
        val causes = listOf(
            AiError.InvalidSchemaJson,
            AiError.TransportFailure,
            AiError.HttpFailure(429),
            AiError.InvalidResponseJson,
            AiError.MissingOutputText,
        )

        for (cause in causes) {
            val presenter = Quiz10InteractionPresenter(
                ControlledGeneration(Outcome.Failure(cause))::generate,
            )
            val result = presenter.present(baseContext)
            val error = assertIs<Quiz10InteractionError.GenerationFailed>(
                assertIs<Outcome.Failure<Quiz10InteractionError>>(result).error,
            )
            assertEquals(cause, error.cause)
        }
    }

    @Test
    fun rejectsBlankMessageAndInvalidStructuredOutputs() {
        val invalidOutputs = listOf(
            "",
            "{bad",
            "null",
            "[]",
            "{}",
            "{\"message\":\"\"}",
            "{\"message\":\"   \"}",
            "{\"message\":1}",
            "{\"message\":\"ok\",\"extra\":\"x\"}",
        )

        for (output in invalidOutputs) {
            val presenter = Quiz10InteractionPresenter(
                ControlledGeneration(Outcome.Success(StructuredGeneration(output, null)))::generate,
            )
            val result = presenter.present(baseContext)
            assertEquals(
                Quiz10InteractionError.InvalidGeneratedMessage,
                assertIs<Outcome.Failure<Quiz10InteractionError>>(result).error,
            )
        }
    }

    @Test
    fun contextValidationEnforcesInteractionRules() {
        assertFailsWith<IllegalArgumentException> {
            Quiz10InteractionContext(
                event = Quiz10InteractionEvent.WELCOME,
                playerName = " ",
                topic = "Historia",
                answeredQuestions = 0,
                correctAnswers = 0,
                totalQuestions = 10,
                stars = 0,
                lastAnswerCorrect = null,
                starEarned = false,
            )
        }
        assertFailsWith<IllegalArgumentException> {
            Quiz10InteractionContext(
                event = Quiz10InteractionEvent.WELCOME,
                playerName = "Ada",
                topic = " ",
                answeredQuestions = 0,
                correctAnswers = 0,
                totalQuestions = 10,
                stars = 0,
                lastAnswerCorrect = null,
                starEarned = false,
            )
        }
        assertFailsWith<IllegalArgumentException> {
            Quiz10InteractionContext(
                event = Quiz10InteractionEvent.WELCOME,
                playerName = "Ada",
                topic = "Historia",
                answeredQuestions = 1,
                correctAnswers = 0,
                totalQuestions = 10,
                stars = 0,
                lastAnswerCorrect = null,
                starEarned = false,
            )
        }
        assertFailsWith<IllegalArgumentException> {
            Quiz10InteractionContext(
                event = Quiz10InteractionEvent.AFTER_ANSWER,
                playerName = "Ada",
                topic = "Historia",
                answeredQuestions = 1,
                correctAnswers = 1,
                totalQuestions = 10,
                stars = 0,
                lastAnswerCorrect = null,
                starEarned = false,
            )
        }
        assertFailsWith<IllegalArgumentException> {
            Quiz10InteractionContext(
                event = Quiz10InteractionEvent.FINISH,
                playerName = "Ada",
                topic = "Historia",
                answeredQuestions = 9,
                correctAnswers = 9,
                totalQuestions = 10,
                stars = 0,
                lastAnswerCorrect = true,
                starEarned = false,
            )
        }
        assertFailsWith<IllegalArgumentException> {
            Quiz10InteractionContext(
                event = Quiz10InteractionEvent.FINISH,
                playerName = "Ada",
                topic = "Historia",
                answeredQuestions = 10,
                correctAnswers = 10,
                totalQuestions = 10,
                stars = 1,
                lastAnswerCorrect = true,
                starEarned = false,
            )
        }

        val finish = Quiz10InteractionContext(
            event = Quiz10InteractionEvent.FINISH,
            playerName = "Ada",
            topic = "Historia",
            answeredQuestions = 10,
            correctAnswers = 10,
            totalQuestions = 10,
            stars = 3,
            lastAnswerCorrect = true,
            starEarned = true,
        )
        assertEquals(Quiz10InteractionEvent.FINISH, finish.event)
    }
}