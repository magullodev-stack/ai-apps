package dev.magullodev.quiz10.systems.quiz10.coverage.terra

import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
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
        return CoverageRoute.of(items.map { element ->
            val fields = requireNotNull(element as? JsonObject)
            require(fields.keys == itemFields)
            fun field(name: String): String {
                val value = requireNotNull(fields[name] as? JsonPrimitive)
                require(value.isString)
                return value.content
            }
            CoverageRouteItem(
                emoji = field("emoji"),
                area = field("area"),
                group = field("group"),
                referent = field("referent"),
                knowledge = field("knowledge"),
                answer = field("answer"),
            )
        })
    }

    private companion object {
        val itemFields = setOf("emoji", "area", "group", "referent", "knowledge", "answer")
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
                      "emoji": {"type": "string"},
                      "area": {"type": "string"},
                      "group": {"type": "string"},
                      "referent": {"type": "string"},
                      "knowledge": {"type": "string"},
                      "answer": {"type": "string"}
                    },
                    "required": ["emoji", "area", "group", "referent", "knowledge", "answer"],
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
