package dev.magullodev.quiz10.systems.quiz10.coverage

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

class CoveragePlanner(
    private val model: String,
    private val generate: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
) {
    fun plan(topic: String): Outcome<CoverageRoute, CoveragePlanningError> {
        val trimmedTopic = topic.trim()
        if (trimmedTopic.isEmpty()) return Outcome.Failure(CoveragePlanningError.BlankTopic)

        val request = StructuredGenerationRequest(
            model = model,
            input = """
                Genera una ruta de cobertura progresiva del tema indicado para Quiz10.
                Devuelve exactamente 10 elementos en este orden: 4 EASY, 3 MODERATE, 2 HARD y 1 VERY_HARD.
                Diversifica las áreas y grupos del tema y no repitas referentes, ignorando mayúsculas y espacios exteriores.
                Cada elemento debe incluir difficulty, area, group, referent, knowledge y answer.
                Los campos textuales deben contener información no vacía sobre el tema.
            """.trimIndent() + "\nTema: $trimmedTopic",
            schemaName = "quiz10_coverage_route",
            schemaJson = schema,
        )
        val generation = when (val result = generate(request)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(CoveragePlanningError.GenerationFailed(result.error))
        }

        return try {
            Outcome.Success(parseRoute(generation.text))
        } catch (_: IllegalArgumentException) {
            Outcome.Failure(CoveragePlanningError.InvalidGeneratedRoute)
        }
    }

    private fun parseRoute(text: String): CoverageRoute {
        val root = requireNotNull(Json.parseToJsonElement(text) as? JsonObject)
        require(root.keys == setOf("items"))
        val generatedItems = requireNotNull(root["items"] as? JsonArray)
        require(generatedItems.size == difficulties.size)
        val items = generatedItems.mapIndexed { index, element ->
            val fields = requireNotNull(element as? JsonObject)
            require(fields.keys == itemFields)
            val difficulty = CoverageDifficulty.valueOf(stringField(fields, "difficulty"))
            require(difficulty == difficulties[index])
            CoverageRouteItem(
                difficulty = difficulty,
                area = textField(fields, "area"),
                group = textField(fields, "group"),
                referent = textField(fields, "referent"),
                knowledge = textField(fields, "knowledge"),
                answer = textField(fields, "answer"),
            )
        }
        return CoverageRoute.of(items)
    }

    private fun stringField(fields: JsonObject, name: String): String {
        val value = requireNotNull(fields[name] as? JsonPrimitive)
        require(value.isString)
        return value.content
    }

    private fun textField(fields: JsonObject, name: String): String =
        stringField(fields, name).trim().also { require(it.isNotEmpty()) }

    private companion object {
        val difficulties = List(4) { CoverageDifficulty.EASY } +
            List(3) { CoverageDifficulty.MODERATE } +
            List(2) { CoverageDifficulty.HARD } +
            CoverageDifficulty.VERY_HARD
        val itemFields = setOf("difficulty", "area", "group", "referent", "knowledge", "answer")
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
                      "answer": {"type": "string"}
                    },
                    "required": ["difficulty", "area", "group", "referent", "knowledge", "answer"],
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
