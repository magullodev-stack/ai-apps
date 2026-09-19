package dev.magullodev.aiapps.systems.games.quiz10.preparation.luna

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRouteItem
import dev.magullodev.aiapps.systems.games.quiz10.question.QuizQuestion
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

class LunaQuizTurnGenerator(
    private val generate: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
) {
    fun generate(
        item: CoverageRouteItem,
        correctOptionIndex: Int,
    ): Outcome<QuizQuestion, QuizTurnGenerationError> {
        if (correctOptionIndex !in 0..3) {
            return Outcome.Failure(QuizTurnGenerationError.InvalidCorrectOptionIndex(correctOptionIndex))
        }

        val area = item.area.trim()
        val group = item.group.trim()
        val referent = item.referent.trim()
        val knowledge = item.knowledge.trim()
        val answer = item.answer.trim()
        if (area.isEmpty() || group.isEmpty() || referent.isEmpty() || knowledge.isEmpty() || answer.isEmpty()) {
            return Outcome.Failure(QuizTurnGenerationError.InvalidCoverageRouteItem)
        }

        val request = StructuredGenerationRequest(
            profile = AiProfile.LUNA,
            input = lunaTurnPrompt(area, group, referent, knowledge, answer),
            schemaName = "quiz10_luna_turn",
            schemaJson = schema,
        )

        val generation = when (val result = generate(request)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(QuizTurnGenerationError.GenerationFailed(result.error))
        }

        return try {
            val parsed = parse(generation.text)
            require(parsed.distractors.none { normalize(it.text) == normalize(answer) })
            val options = parsed.distractors.map { it.text }.toMutableList()
            val feedback = parsed.distractors.map { it.explanation }.toMutableList()
            options.add(correctOptionIndex, answer)
            feedback.add(correctOptionIndex, parsed.correctExplanation)
            Outcome.Success(
                QuizQuestion(
                    text = parsed.question,
                    options = options,
                    feedbackByOption = feedback,
                    correctOptionIndex = correctOptionIndex,
                ),
            )
        } catch (_: IllegalArgumentException) {
            Outcome.Failure(QuizTurnGenerationError.InvalidGeneratedTurn)
        }
    }

    private fun parse(text: String): ParsedTurn {
        val root = requireNotNull(Json.parseToJsonElement(text) as? JsonObject)
        require(root.keys == setOf("question", "correctExplanation", "distractors"))

        val question = textField(root, "question")
        val correctExplanation = textField(root, "correctExplanation")

        val distractorsArray = requireNotNull(root["distractors"] as? JsonArray)
        require(distractorsArray.size == 3)
        val distractors = distractorsArray.map { element ->
            val fields = requireNotNull(element as? JsonObject)
            require(fields.keys == setOf("text", "explanation"))
            ParsedDistractor(
                text = textField(fields, "text"),
                explanation = textField(fields, "explanation"),
            )
        }

        val normalizedDistractors = distractors.map { normalize(it.text) }
        require(normalizedDistractors.toSet().size == 3)

        return ParsedTurn(
            question = question,
            correctExplanation = correctExplanation,
            distractors = distractors,
        )
    }

    private fun textField(fields: JsonObject, name: String): String {
        val value = requireNotNull(fields[name] as? JsonPrimitive)
        require(value.isString)
        val content = value.content.trim()
        require(content.isNotEmpty())
        return content
    }

    private fun normalize(text: String): String = text.trim().lowercase()

    private data class ParsedTurn(
        val question: String,
        val correctExplanation: String,
        val distractors: List<ParsedDistractor>,
    )

    private data class ParsedDistractor(
        val text: String,
        val explanation: String,
    )

    private companion object {
        val schema = """
            {
              "type": "object",
              "properties": {
                "question": {"type": "string"},
                "correctExplanation": {"type": "string"},
                "distractors": {
                  "type": "array",
                  "minItems": 3,
                  "maxItems": 3,
                  "items": {
                    "type": "object",
                    "properties": {
                      "text": {"type": "string"},
                      "explanation": {"type": "string"}
                    },
                    "required": ["text", "explanation"],
                    "additionalProperties": false
                  }
                }
              },
              "required": ["question", "correctExplanation", "distractors"],
              "additionalProperties": false
            }
        """.trimIndent()
    }
}

sealed interface QuizTurnGenerationError {
    data object InvalidCoverageRouteItem : QuizTurnGenerationError
    data class InvalidCorrectOptionIndex(val index: Int) : QuizTurnGenerationError
    data class GenerationFailed(val cause: AiError) : QuizTurnGenerationError
    data object InvalidGeneratedTurn : QuizTurnGenerationError
}
