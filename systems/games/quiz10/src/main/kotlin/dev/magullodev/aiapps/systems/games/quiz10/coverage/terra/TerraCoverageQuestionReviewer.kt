package dev.magullodev.aiapps.systems.games.quiz10.coverage.terra

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.AiUsageOperation
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.prompts.random.test.validacionYPreguntasPrompt
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import java.util.Collections

class TerraCoverageQuestionReviewer(
    private val generate: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
) {
    fun review(route: CoverageRoute): Outcome<CoverageQuestionReview, CoverageQuestionReviewError> {
        val request = StructuredGenerationRequest(
            profile = AiProfile.TERRA,
            input = validacionYPreguntasPrompt(route),
            schemaName = "quiz10_coverage_question_review",
            schemaJson = schema,
            operation = AiUsageOperation.REVIEW,
        )

        val generation = when (val result = generate(request)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(CoverageQuestionReviewError.GenerationFailed(result.error))
        }

        return try {
            Outcome.Success(parse(generation.text, route))
        } catch (_: IllegalArgumentException) {
            Outcome.Failure(CoverageQuestionReviewError.InvalidStructuredResponse)
        }
    }

    private fun parse(text: String, route: CoverageRoute): CoverageQuestionReview {
        val root = requireNotNull(Json.parseToJsonElement(text) as? JsonObject)
        require(root.keys == setOf("items"))

        val items = requireNotNull(root["items"] as? JsonArray)
        require(items.size == expectedItems)

        val seenQuestions = mutableSetOf<String>()
        val reviewed = items.mapIndexed { index, element ->
            val fields = requireNotNull(element as? JsonObject)
            require(fields.keys == itemFields)

            val validValue = requireNotNull(fields["valid"] as? JsonPrimitive)
            require(!validValue.isString)
            val valid = validValue.booleanOrNull ?: throw IllegalArgumentException("valid must be boolean")

            val issue = textField(fields, "issue")
            val question = textField(fields, "question")
            val answer = textField(fields, "answer")
            val distractor1 = textField(fields, "distractor1")
            val distractor2 = textField(fields, "distractor2")
            val distractor3 = textField(fields, "distractor3")

            val reviewedPosition = if (valid) {
                localValidationForDeclaredValid(
                    issue = issue,
                    question = question,
                    answer = answer,
                    distractor1 = distractor1,
                    distractor2 = distractor2,
                    distractor3 = distractor3,
                    expectedAnswer = route.items[index].answer,
                    seenQuestions = seenQuestions,
                )
            } else {
                localValidationForDeclaredInvalid(
                    issue = issue,
                    question = question,
                    answer = answer,
                    distractor1 = distractor1,
                    distractor2 = distractor2,
                    distractor3 = distractor3,
                )
            }

            reviewedPosition
        }

        return CoverageQuestionReview.of(reviewed)
    }

    private fun textField(fields: JsonObject, name: String): String {
        val value = requireNotNull(fields[name] as? JsonPrimitive)
        require(value.isString)
        return value.content
    }

    private fun localValidationForDeclaredValid(
        issue: String,
        question: String,
        answer: String,
        distractor1: String,
        distractor2: String,
        distractor3: String,
        expectedAnswer: String,
        seenQuestions: MutableSet<String>,
    ): CoverageQuestionReviewPosition {
        val issueText = issue.trim()
        if (issueText.isNotEmpty()) {
            return CoverageQuestionReviewPosition.Invalid("Fila marcada como válida pero con incidencia informada")
        }

        val normalizedQuestion = normalize(question)
        if (normalizedQuestion.isEmpty()) {
            return CoverageQuestionReviewPosition.Invalid("Fila marcada como válida sin pregunta")
        }

        val normalizedAnswer = normalize(answer)
        if (normalizedAnswer.isEmpty()) {
            return CoverageQuestionReviewPosition.Invalid("Fila marcada como válida sin respuesta")
        }
        if (normalizedAnswer != normalize(expectedAnswer)) {
            return CoverageQuestionReviewPosition.Invalid("La respuesta propuesta no coincide con la ruta de cobertura")
        }

        val distractors = listOf(distractor1, distractor2, distractor3)
        val normalizedDistractors = distractors.map(::normalize)
        if (normalizedDistractors.any { it.isEmpty() }) {
            return CoverageQuestionReviewPosition.Invalid("Fila marcada como válida con distractores incompletos")
        }
        if (normalizedDistractors.toSet().size != 3) {
            return CoverageQuestionReviewPosition.Invalid("Fila marcada como válida con distractores repetidos")
        }
        if (normalizedDistractors.any { it == normalizedAnswer }) {
            return CoverageQuestionReviewPosition.Invalid("Fila marcada como válida con distractor igual a la respuesta correcta")
        }

        if (!seenQuestions.add(normalizedQuestion)) {
            return CoverageQuestionReviewPosition.Invalid("Enunciado de pregunta repetido respecto a una fila previa")
        }

        return CoverageQuestionReviewPosition.Valid(
            question = question.trim(),
            answer = answer.trim(),
            distractors = distractors.map { it.trim() },
        )
    }

    private fun localValidationForDeclaredInvalid(
        issue: String,
        question: String,
        answer: String,
        distractor1: String,
        distractor2: String,
        distractor3: String,
    ): CoverageQuestionReviewPosition {
        val issueText = issue.trim()
        val hasUnexpectedContent = listOf(question, answer, distractor1, distractor2, distractor3)
            .any { it.trim().isNotEmpty() }

        return when {
            issueText.isEmpty() -> CoverageQuestionReviewPosition.Invalid("Fila inválida sin incidencia informada")
            hasUnexpectedContent -> CoverageQuestionReviewPosition.Invalid("Fila inválida con contenido utilizable en campos no permitidos")
            else -> CoverageQuestionReviewPosition.Invalid(issueText)
        }
    }

    private fun normalize(text: String): String = text.trim().lowercase()

    private companion object {
        const val expectedItems = 10

        val itemFields = setOf(
            "valid",
            "issue",
            "question",
            "answer",
            "distractor1",
            "distractor2",
            "distractor3",
        )

        val schema = """
            {
              "type": "object",
              "properties": {
                "items": {
                  "type": "array",
                  "minItems": 10,
                  "maxItems": 10,
                  "items": {
                    "type": "object",
                    "properties": {
                      "valid": {"type": "boolean"},
                      "issue": {"type": "string"},
                      "question": {"type": "string"},
                      "answer": {"type": "string"},
                      "distractor1": {"type": "string"},
                      "distractor2": {"type": "string"},
                      "distractor3": {"type": "string"}
                    },
                    "required": ["valid", "issue", "question", "answer", "distractor1", "distractor2", "distractor3"],
                    "additionalProperties": false
                  }
                }
              },
              "required": ["items"],
              "additionalProperties": false
            }
        """.trimIndent()
    }
}

class CoverageQuestionReview private constructor(
    val positions: List<CoverageQuestionReviewPosition>,
) {
    companion object {
        fun of(positions: List<CoverageQuestionReviewPosition>): CoverageQuestionReview {
            val snapshot = positions.toList()
            require(snapshot.size == 10) { "Coverage question review must contain exactly 10 positions" }
            return CoverageQuestionReview(Collections.unmodifiableList(snapshot))
        }
    }
}

sealed interface CoverageQuestionReviewPosition {
    data class Valid(
        val question: String,
        val answer: String,
        val distractors: List<String>,
    ) : CoverageQuestionReviewPosition {
        init {
            require(question.isNotBlank()) { "Question must not be blank" }
            require(answer.isNotBlank()) { "Answer must not be blank" }
            require(distractors.size == 3) { "Exactly three distractors are required" }
            require(distractors.all { it.isNotBlank() }) { "Distractors must not be blank" }
        }
    }

    data class Invalid(
        val issue: String,
    ) : CoverageQuestionReviewPosition {
        init {
            require(issue.isNotBlank()) { "Issue must not be blank" }
        }
    }
}

sealed interface CoverageQuestionReviewError {
    data class GenerationFailed(val cause: AiError) : CoverageQuestionReviewError
    data object InvalidStructuredResponse : CoverageQuestionReviewError
}