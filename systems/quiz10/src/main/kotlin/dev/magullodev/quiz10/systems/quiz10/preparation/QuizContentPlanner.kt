package dev.magullodev.quiz10.systems.quiz10.preparation

import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageDifficulty
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

class QuizContentPlanner(
    private val generate: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
) {
    fun plan(topic: String): Outcome<QuizContentPlan, QuizContentPlanningError> {
        val trimmedTopic = topic.trim()
        if (trimmedTopic.isEmpty()) return Outcome.Failure(QuizContentPlanningError.BlankTopic)

        val request = StructuredGenerationRequest(
            profile = AiProfile.TERRA,
            input = """
                Genera el contenido factual completo de un Quiz10 sobre el tema indicado.
                Devuelve exactamente 10 elementos completos en este orden: 4 EASY, 3 MODERATE, 2 HARD y 1 VERY_HARD.
                Diversifica áreas y grupos, no repitas referentes ignorando mayúsculas y espacios exteriores.
                Cada elemento debe incluir: difficulty, area, group, referent, knowledge, answer, question,
                correctExplanation y exactamente tres distractors.
                Cada distractor debe incluir text y explanation.
                Los campos textuales deben ser no vacíos.
                Cada pregunta debe ser inequívoca y coherente con knowledge, referent, group y area.
                Los tres distractores de cada elemento deben ser distintos entre sí y distintos de la answer.
                La respuesta correcta sigue siendo answer; no decidas posiciones A/B/C/D.
            """.trimIndent() + "\nTema: $trimmedTopic",
            schemaName = "quiz10_content_plan",
            schemaJson = schema,
        )

        val generation = when (val result = generate(request)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(QuizContentPlanningError.GenerationFailed(result.error))
        }

        return try {
            Outcome.Success(parsePlan(generation.text))
        } catch (_: IllegalArgumentException) {
            Outcome.Failure(QuizContentPlanningError.InvalidGeneratedPlan)
        }
    }

    private fun parsePlan(text: String): QuizContentPlan {
        val root = requireNotNull(Json.parseToJsonElement(text) as? JsonObject)
        require(root.keys == setOf("items"))
        val generatedItems = requireNotNull(root["items"] as? JsonArray)
        require(generatedItems.size == expectedDifficulties.size)

        val items = generatedItems.mapIndexed { index, element ->
            val fields = requireNotNull(element as? JsonObject)
            require(fields.keys == itemFields)

            val difficulty = CoverageDifficulty.valueOf(stringField(fields, "difficulty"))
            require(difficulty == expectedDifficulties[index])

            val distractorsArray = requireNotNull(fields["distractors"] as? JsonArray)
            require(distractorsArray.size == 3)

            val distractors = distractorsArray.map { distractor ->
                val distractorObject = requireNotNull(distractor as? JsonObject)
                require(distractorObject.keys == distractorFields)
                QuizContentDistractor(
                    text = textField(distractorObject, "text"),
                    explanation = textField(distractorObject, "explanation"),
                )
            }

            QuizContentPlanItem(
                difficulty = difficulty,
                area = textField(fields, "area"),
                group = textField(fields, "group"),
                referent = textField(fields, "referent"),
                knowledge = textField(fields, "knowledge"),
                answer = textField(fields, "answer"),
                question = textField(fields, "question"),
                correctExplanation = textField(fields, "correctExplanation"),
                distractors = distractors,
            )
        }

        return QuizContentPlan.of(items)
    }

    private fun stringField(fields: JsonObject, name: String): String {
        val value = requireNotNull(fields[name] as? JsonPrimitive)
        require(value.isString)
        return value.content
    }

    private fun textField(fields: JsonObject, name: String): String =
        stringField(fields, name).trim().also { require(it.isNotEmpty()) }

    private companion object {
        val expectedDifficulties = List(4) { CoverageDifficulty.EASY } +
            List(3) { CoverageDifficulty.MODERATE } +
            List(2) { CoverageDifficulty.HARD } +
            CoverageDifficulty.VERY_HARD

        val distractorFields = setOf("text", "explanation")
        val itemFields = setOf(
            "difficulty",
            "area",
            "group",
            "referent",
            "knowledge",
            "answer",
            "question",
            "correctExplanation",
            "distractors",
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
                      "difficulty": {"type": "string", "enum": ["EASY", "MODERATE", "HARD", "VERY_HARD"]},
                      "area": {"type": "string"},
                      "group": {"type": "string"},
                      "referent": {"type": "string"},
                      "knowledge": {"type": "string"},
                      "answer": {"type": "string"},
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
                    "required": [
                      "difficulty",
                      "area",
                      "group",
                      "referent",
                      "knowledge",
                      "answer",
                      "question",
                      "correctExplanation",
                      "distractors"
                    ],
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
