package dev.magullodev.aiapps.systems.games.quiz10.coverage.terra

import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficultyByPosition
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRouteItem
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlan
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

class TerraCoverageRouteGenerator(
    private val generate: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
) {
    fun generate(plan: StandardCoveragePlan): Outcome<CoverageRoute, CoverageRouteGenerationError> {
        val request = StructuredGenerationRequest(
            profile = AiProfile.TERRA,
            input = terraCoveragePrompt(plan),
            schemaName = "quiz10_coverage_route_from_plan",
            schemaJson = planSchema,
        )
        val generation = when (val result = generate(request)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(CoverageRouteGenerationError.GenerationFailed(result.error))
        }
        return try {
            Outcome.Success(parseForPlan(generation.text, plan))
        } catch (_: IllegalArgumentException) {
            Outcome.Failure(CoverageRouteGenerationError.InvalidGeneratedRoute)
        }
    }

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
                difficulty = CoverageDifficultyByPosition.forPosition(index + 1),
                area = field("area"),
                group = field("group"),
                referent = field("referent"),
                knowledge = field("knowledge"),
                answer = field("answer"),
            )
        })
    }

    private fun parseForPlan(text: String, plan: StandardCoveragePlan): CoverageRoute {
        val root = requireNotNull(Json.parseToJsonElement(text) as? JsonObject)
        require(root.keys == setOf("items"))
        val items = requireNotNull(root["items"] as? JsonArray)
        require(items.size == expectedItems)
        return CoverageRoute.of(items.mapIndexed { index, element ->
            val fields = requireNotNull(element as? JsonObject)
            require(fields.keys == planItemFields)
            fun field(name: String): String {
                val value = requireNotNull(fields[name] as? JsonPrimitive)
                require(value.isString)
                val content = value.content
                require(content.isNotBlank())
                return content
            }

            val position = plan.positions[index]
            CoverageRouteItem(
                difficulty = position.difficulty,
                area = position.area.label,
                group = field("group"),
                referent = field("referent"),
                knowledge = field("knowledge"),
                answer = field("answer"),
            )
        })
    }

    private companion object {
        const val expectedItems = 10
        val planItemFields = setOf("group", "referent", "knowledge", "answer")
        val itemFields = setOf("area", "group", "referent", "knowledge", "answer")

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

                val planSchema = """
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
                                            "group": {"type": "string"},
                                            "referent": {"type": "string"},
                                            "knowledge": {"type": "string"},
                                            "answer": {"type": "string"}
                                        },
                                        "required": ["group", "referent", "knowledge", "answer"],
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
