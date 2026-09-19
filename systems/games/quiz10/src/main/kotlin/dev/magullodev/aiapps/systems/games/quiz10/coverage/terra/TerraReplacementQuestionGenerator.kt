package dev.magullodev.aiapps.systems.games.quiz10.coverage.terra

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.intOrNull
import java.util.Collections

class TerraReplacementQuestionGenerator(
    private val generate: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
) {
    fun generate(
        pendingPositions: List<ReplacementQuestionPosition>,
        acceptedQuestions: List<AcceptedCoverageQuestion>,
    ): Outcome<ReplacementQuestionBatch, ReplacementQuestionGenerationError> {
        val targets = pendingPositions.toList()
        require(targets.isNotEmpty()) { "At least one replacement position is required" }
        require(targets.map { it.position }.toSet().size == targets.size) { "Replacement positions must be unique" }

        val request = StructuredGenerationRequest(
            profile = AiProfile.TERRA,
            input = terraReplacementQuestionPrompt(targets, acceptedQuestions),
            schemaName = "quiz10_replacement_questions",
            schemaJson = schemaJson(targets.size),
        )

        val generation = when (val result = generate(request)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(ReplacementQuestionGenerationError.GenerationFailed(result.error))
        }

        return try {
            Outcome.Success(parse(generation.text, targets, acceptedQuestions))
        } catch (_: IllegalArgumentException) {
            Outcome.Failure(ReplacementQuestionGenerationError.InvalidStructuredResponse)
        }
    }

    private fun parse(
        text: String,
        pendingPositions: List<ReplacementQuestionPosition>,
        acceptedQuestions: List<AcceptedCoverageQuestion>,
    ): ReplacementQuestionBatch {
        val root = requireNotNull(Json.parseToJsonElement(text) as? JsonObject)
        require(root.keys == setOf("items"))
        val items = requireNotNull(root["items"] as? JsonArray)
        require(items.size == pendingPositions.size)

        val pendingByPosition = pendingPositions.associateBy { it.position }
        val rawRows = items.map { element ->
            val fields = requireNotNull(element as? JsonObject)
            require(fields.keys == itemFields)

            val positionPrimitive = requireNotNull(fields["position"] as? JsonPrimitive)
            require(!positionPrimitive.isString)
            val position = positionPrimitive.intOrNull ?: throw IllegalArgumentException("position must be integer")

            RawReplacement(
                position = position,
                question = textField(fields, "question"),
                answer = textField(fields, "answer"),
                distractor1 = textField(fields, "distractor1"),
                distractor2 = textField(fields, "distractor2"),
                distractor3 = textField(fields, "distractor3"),
            )
        }

        val positions = rawRows.map { it.position }
        require(positions.toSet().size == positions.size)
        require(positions.toSet() == pendingByPosition.keys)

        val normalizedAcceptedQuestions = acceptedQuestions.map { normalize(it.question) }.toSet()
        val seenBatchQuestions = mutableSetOf<String>()
        val rawByPosition = rawRows.associateBy { it.position }

        val results = pendingPositions.map { target ->
            val raw = checkNotNull(rawByPosition[target.position])
            val question = raw.question.trim()
            val answer = raw.answer.trim()
            val distractors = listOf(raw.distractor1.trim(), raw.distractor2.trim(), raw.distractor3.trim())

            val localError = localValidationError(question, answer, distractors, normalizedAcceptedQuestions, seenBatchQuestions)
            if (localError != null) {
                ReplacementQuestionResult(
                    position = target.position,
                    outcome = ReplacementQuestionOutcome.Invalid(localError),
                )
            } else {
                seenBatchQuestions += normalize(question)
                ReplacementQuestionResult(
                    position = target.position,
                    outcome = ReplacementQuestionOutcome.Valid(
                        question = question,
                        answer = answer,
                        distractors = distractors,
                    ),
                )
            }
        }

        return ReplacementQuestionBatch.of(results)
    }

    private fun localValidationError(
        question: String,
        answer: String,
        distractors: List<String>,
        normalizedAcceptedQuestions: Set<String>,
        seenBatchQuestions: Set<String>,
    ): String? {
        val normalizedQuestion = normalize(question)
        if (normalizedQuestion.isEmpty()) return "Pregunta vacía"

        val normalizedAnswer = normalize(answer)
        if (normalizedAnswer.isEmpty()) return "Respuesta vacía"

        if (distractors.size != 3) return "Se requieren exactamente tres distractores"

        val normalizedDistractors = distractors.map(::normalize)
        if (normalizedDistractors.any { it.isEmpty() }) return "Distractores incompletos"
        if (normalizedDistractors.toSet().size != 3) return "Distractores repetidos"
        if (normalizedDistractors.any { it == normalizedAnswer }) return "Un distractor coincide con la respuesta correcta"

        if (normalizedQuestion in normalizedAcceptedQuestions) {
            return "La pregunta coincide con una ya aceptada"
        }
        if (normalizedQuestion in seenBatchQuestions) {
            return "La pregunta coincide con otra sustitución del mismo lote"
        }

        return null
    }

    private fun textField(fields: JsonObject, name: String): String {
        val primitive = requireNotNull(fields[name] as? JsonPrimitive)
        require(primitive.isString)
        return primitive.content
    }

    private fun normalize(text: String): String = text.trim().lowercase()

    private fun schemaJson(itemCount: Int): String =
        """
            {
              "type": "object",
              "properties": {
                "items": {
                  "type": "array",
                  "minItems": $itemCount,
                  "maxItems": $itemCount,
                  "items": {
                    "type": "object",
                    "properties": {
                      "position": {"type": "integer"},
                      "question": {"type": "string"},
                      "answer": {"type": "string"},
                      "distractor1": {"type": "string"},
                      "distractor2": {"type": "string"},
                      "distractor3": {"type": "string"}
                    },
                    "required": ["position", "question", "answer", "distractor1", "distractor2", "distractor3"],
                    "additionalProperties": false
                  }
                }
              },
              "required": ["items"],
              "additionalProperties": false
            }
        """.trimIndent()

    private data class RawReplacement(
        val position: Int,
        val question: String,
        val answer: String,
        val distractor1: String,
        val distractor2: String,
        val distractor3: String,
    )

    private companion object {
        val itemFields = setOf("position", "question", "answer", "distractor1", "distractor2", "distractor3")
    }
}

data class ReplacementQuestionPosition(
    val position: Int,
    val areaLabel: String,
    val difficulty: CoverageDifficulty,
) {
    init {
        require(position in 1..10) { "Position must be between 1 and 10" }
        require(areaLabel.isNotBlank()) { "Area label must not be blank" }
    }
}

data class AcceptedCoverageQuestion(
    val position: Int,
    val question: String,
    val answer: String,
) {
    init {
        require(position in 1..10) { "Position must be between 1 and 10" }
        require(question.isNotBlank()) { "Question must not be blank" }
        require(answer.isNotBlank()) { "Answer must not be blank" }
    }
}

class ReplacementQuestionBatch private constructor(
    val results: List<ReplacementQuestionResult>,
) {
    companion object {
        fun of(results: List<ReplacementQuestionResult>): ReplacementQuestionBatch {
            val snapshot = results.toList()
            require(snapshot.isNotEmpty()) { "Replacement batch must not be empty" }
            require(snapshot.map { it.position }.toSet().size == snapshot.size) {
                "Replacement batch positions must be unique"
            }
            return ReplacementQuestionBatch(Collections.unmodifiableList(snapshot))
        }
    }
}

data class ReplacementQuestionResult(
    val position: Int,
    val outcome: ReplacementQuestionOutcome,
) {
    init {
        require(position in 1..10) { "Position must be between 1 and 10" }
    }
}

sealed interface ReplacementQuestionOutcome {
    data class Valid(
        val question: String,
        val answer: String,
        val distractors: List<String>,
    ) : ReplacementQuestionOutcome {
        init {
            require(question.isNotBlank()) { "Question must not be blank" }
            require(answer.isNotBlank()) { "Answer must not be blank" }
            require(distractors.size == 3) { "Exactly three distractors are required" }
            require(distractors.all { it.isNotBlank() }) { "Distractors must not be blank" }
        }
    }

    data class Invalid(
        val issue: String,
    ) : ReplacementQuestionOutcome {
        init {
            require(issue.isNotBlank()) { "Issue must not be blank" }
        }
    }
}

sealed interface ReplacementQuestionGenerationError {
    data class GenerationFailed(val cause: AiError) : ReplacementQuestionGenerationError
    data object InvalidStructuredResponse : ReplacementQuestionGenerationError
}
