package dev.magullodev.quiz10.systems.quiz10.interaction

import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

class Quiz10InteractionPresenter(
    private val profile: AiProfile,
    private val generate: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
) {
    fun present(context: Quiz10InteractionContext): Outcome<Quiz10InteractionMessage, Quiz10InteractionError> {
        val request = StructuredGenerationRequest(
            profile = profile,
            input = buildPrompt(context),
            schemaName = "quiz10_interaction_message",
            schemaJson = schema,
        )

        val generation = when (val result = generate(request)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(Quiz10InteractionError.GenerationFailed(result.error))
        }

        return try {
            Outcome.Success(parseMessage(generation.text))
        } catch (_: IllegalArgumentException) {
            Outcome.Failure(Quiz10InteractionError.InvalidGeneratedMessage)
        }
    }

    private fun parseMessage(text: String): Quiz10InteractionMessage {
        val root = requireNotNull(Json.parseToJsonElement(text) as? JsonObject)
        require(root.keys == setOf("message"))
        val message = requireNotNull(root["message"] as? JsonPrimitive)
        require(message.isString)
        return Quiz10InteractionMessage(message.content.trim())
    }

    private fun buildPrompt(context: Quiz10InteractionContext): String = """
        Eres Luna, presentadora lateral de Quiz10.
        Escribe en español de España y devuelve UNA sola pieza JSON con el campo message.
        message debe tener una o dos frases como máximo.
        Tu comentario SOLO puede usar los hechos de este contexto:
        - evento: ${context.event}
        - jugador: ${context.playerName}
        - tema: ${context.topic}
        - respondidas: ${context.answeredQuestions}/${context.totalQuestions}
        - aciertos: ${context.correctAnswers}
        - fallos: ${context.answeredQuestions - context.correctAnswers}
        - estrellas: ${context.stars}
        - último acierto: ${context.lastAnswerCorrect?.toString() ?: "null"}
        - estrella ganada en esta partida: ${context.starEarned}

        Puedes dar la bienvenida, felicitar, animar, reaccionar a acierto/fallo, cerrar la partida
        y mencionar la estrella cuando estrella ganada en esta partida sea true.

        Prohibido:
        - aportar conocimiento factual del tema
        - explicar respuestas
        - dar pistas
        - inventar estadísticas
        - alterar o contradecir el estado del contexto
    """.trimIndent()

    private companion object {
        val schema = """
            {
              "type": "object",
              "properties": {
                "message": { "type": "string" }
              },
              "required": ["message"],
              "additionalProperties": false
            }
        """.trimIndent()
    }
}