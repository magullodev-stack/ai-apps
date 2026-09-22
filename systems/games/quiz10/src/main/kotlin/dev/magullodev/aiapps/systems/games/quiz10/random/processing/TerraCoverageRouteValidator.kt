package dev.magullodev.aiapps.systems.games.quiz10.random.processing
import dev.magullodev.aiapps.systems.games.quiz10.random.prompts.terraCoverageRouteValidationPrompt

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.AiUsageOperation
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull

class TerraCoverageRouteValidator(
    private val generate: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
) {
    fun validate(topic: String, route: CoverageRoute): Outcome<Unit, CoverageRouteValidationError> {
        val request = StructuredGenerationRequest(
            profile = AiProfile.TERRA,
            input = terraCoverageRouteValidationPrompt(topic, route),
            schemaName = "quiz10_coverage_route_validation",
            schemaJson = schema,
            operation = AiUsageOperation.COVERAGE,
        )

        val generation = when (val result = generate(request)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(CoverageRouteValidationError.GenerationFailed(result.error))
        }

        return try {
            val review = parse(generation.text)
            if (review.approved) {
                Outcome.Success(Unit)
            } else {
                Outcome.Failure(CoverageRouteValidationError.RouteRejected(review.issues))
            }
        } catch (_: IllegalArgumentException) {
            Outcome.Failure(CoverageRouteValidationError.InvalidStructuredResponse)
        }
    }

    private fun parse(text: String): ParsedValidation {
        val root = requireNotNull(Json.parseToJsonElement(text) as? JsonObject)
        require(root.keys == setOf("approved", "issues"))

        val approvedValue = requireNotNull(root["approved"] as? JsonPrimitive)
        require(!approvedValue.isString)
        val approved = approvedValue.booleanOrNull ?: throw IllegalArgumentException("approved must be boolean")

        val issuesArray = requireNotNull(root["issues"] as? JsonArray)
        val issues = issuesArray.map { element ->
            val primitive = requireNotNull(element as? JsonPrimitive)
            require(primitive.isString)
            val issue = primitive.content.trim()
            require(issue.isNotEmpty())
            issue
        }

        if (approved) {
            require(issues.isEmpty())
        } else {
            require(issues.isNotEmpty())
        }

        return ParsedValidation(approved = approved, issues = issues)
    }

    private data class ParsedValidation(
        val approved: Boolean,
        val issues: List<String>,
    )

    private companion object {
        val schema = """
            {
              "type": "object",
              "properties": {
                "approved": { "type": "boolean" },
                "issues": {
                  "type": "array",
                  "items": { "type": "string" }
                }
              },
              "required": ["approved", "issues"],
              "additionalProperties": false
            }
        """.trimIndent()
    }
}

sealed interface CoverageRouteValidationError {
    data class GenerationFailed(val cause: AiError) : CoverageRouteValidationError
    data object InvalidStructuredResponse : CoverageRouteValidationError
    data class RouteRejected(val issues: List<String>) : CoverageRouteValidationError
}
