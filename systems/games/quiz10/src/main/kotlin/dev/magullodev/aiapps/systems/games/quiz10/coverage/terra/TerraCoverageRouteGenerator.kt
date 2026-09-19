package dev.magullodev.aiapps.systems.games.quiz10.coverage.terra

import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRouteItem
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

class TerraCoverageRouteGenerator(
    private val generate: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
) {
    fun generate(topic: String): Outcome<CoverageRoute, CoverageRouteGenerationError> {
        if (topic.isBlank()) return Outcome.Failure(CoverageRouteGenerationError.BlankTopic)
        val request = StructuredGenerationRequest(
            profile = AiProfile.TERRA,
            input = terraCoveragePrompt(topic),
            schemaName = "quiz10_coverage_route",
            schemaJson = schema,
        )
        val generation = when (val result = generate(request)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(CoverageRouteGenerationError.GenerationFailed(result.error))
        }
        return try {
            Outcome.Success(parse(generation.text))
        } catch (_: IllegalArgumentException) {
            Outcome.Failure(CoverageRouteGenerationError.InvalidGeneratedRoute)
        }
    }

    private fun parse(text: String): CoverageRoute {
        val root = requireNotNull(Json.parseToJsonElement(text) as? JsonObject)
        require(root.keys == setOf("items"))
        val items = requireNotNull(root["items"] as? JsonArray)
        require(items.size == expectedItems)
        return CoverageRoute.of(items.mapIndexed { index, element ->
            val fields = requireNotNull(element as? JsonObject)
            require(fields.keys == itemFields)
            fun field(name: String): String {
                val value = requireNotNull(fields[name] as? JsonPrimitive)
                require(value.isString)
                val content = value.content
                require(content.isNotBlank())
                return content
            }
            CoverageRouteItem(
                difficulty = difficultyForPosition(index + 1),
                area = field("area"),
                group = field("group"),
                referent = field("referent"),
                knowledge = field("knowledge"),
                answer = field("answer"),
            )
        })
    }

    private companion object {
        const val expectedItems = 10
        val itemFields = setOf("area", "group", "referent", "knowledge", "answer")

        fun difficultyForPosition(position: Int): CoverageDifficulty =
            when (position) {
                in 1..4 -> CoverageDifficulty.EASY
                in 5..7 -> CoverageDifficulty.MODERATE
                in 8..9 -> CoverageDifficulty.HARD
                10 -> CoverageDifficulty.VERY_HARD
                else -> throw IllegalArgumentException("Coverage position must be between 1 and 10")
            }

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
                      "area": {"type": "string"},
                      "group": {"type": "string"},
                      "referent": {"type": "string"},
                      "knowledge": {"type": "string"},
                      "answer": {"type": "string"}
                    },
                                        "required": ["area", "group", "referent", "knowledge", "answer"],
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

sealed interface CoverageRouteGenerationError {
    data object BlankTopic : CoverageRouteGenerationError
    data class GenerationFailed(val cause: AiError) : CoverageRouteGenerationError
    data object InvalidGeneratedRoute : CoverageRouteGenerationError
}
