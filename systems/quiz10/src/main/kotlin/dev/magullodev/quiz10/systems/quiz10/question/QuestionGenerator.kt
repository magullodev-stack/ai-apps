package dev.magullodev.quiz10.systems.quiz10.question

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRouteItem
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

class QuestionGenerator(
    private val model: String,
    private val generateStructured: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
) {
    init {
        require(model.isNotBlank()) { "Question model must not be blank" }
    }

    fun generate(item: CoverageRouteItem, correctOptionIndex: Int): Outcome<QuizQuestion, QuestionGenerationError> {
        require(correctOptionIndex in 0..3) { "Correct option index must be between 0 and 3" }

        val request = StructuredGenerationRequest(
            model = model,
            input = """
                Genera una pregunta breve para Quiz10 que evalúe exactamente knowledge sobre referent.
                Incluye el contexto necesario de group y area para que la pregunta sea inequívoca.
                La respuesta correcta es answer. Devuelve la pregunta en question y exactamente tres
                alternativas plausibles pero falsas en distractors, distintas entre sí y de answer.
                Las cuatro opciones deben ser breves y comparables en extensión y precisión.
                area: ${item.area}
                group: ${item.group}
                referent: ${item.referent}
                knowledge: ${item.knowledge}
                answer: ${item.answer}
            """.trimIndent(),
            schemaName = "quiz10_question",
            schemaJson = schema,
        )
        val generation = when (val result = generateStructured(request)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(QuestionGenerationError.GenerationFailed(result.error))
        }

        return try {
            Outcome.Success(parseQuestion(generation.text, item.answer, correctOptionIndex))
        } catch (_: IllegalArgumentException) {
            Outcome.Failure(QuestionGenerationError.InvalidGeneratedQuestion)
        }
    }

    private fun parseQuestion(text: String, answer: String, correctOptionIndex: Int): QuizQuestion {
        val fields = requireNotNull(Json.parseToJsonElement(text) as? JsonObject)
        require(fields.keys == setOf("question", "distractors"))
        val question = textValue(fields["question"])
        val distractors = requireNotNull(fields["distractors"] as? JsonArray)
        require(distractors.size == 3)
        val options = distractors.map { textValue(it) }.toMutableList()
        val normalized = options.map { it.lowercase() }
        require(normalized.toSet().size == 3)
        require(answer.trim().lowercase() !in normalized)
        options.add(correctOptionIndex, answer)
        return QuizQuestion(question, options, correctOptionIndex)
    }

    private fun textValue(element: JsonElement?): String {
        val value = requireNotNull(element as? JsonPrimitive)
        require(value.isString)
        return value.content.trim().also { require(it.isNotEmpty()) }
    }

    private companion object {
        val schema = """
            {
              "type": "object",
              "properties": {
                "question": {"type": "string"},
                "distractors": {
                  "type": "array",
                  "minItems": 3,
                  "maxItems": 3,
                  "items": {"type": "string"}
                }
              },
              "required": ["question", "distractors"],
              "additionalProperties": false
            }
        """.trimIndent()
    }
}
