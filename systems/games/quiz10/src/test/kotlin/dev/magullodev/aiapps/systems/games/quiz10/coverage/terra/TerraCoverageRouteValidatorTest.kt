package dev.magullodev.aiapps.systems.games.quiz10.coverage.terra

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRouteItem
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertIs

class TerraCoverageRouteValidatorTest {
    private fun route(): CoverageRoute = CoverageRoute.of(List(10) { index ->
        CoverageRouteItem(
            difficulty = when (index) {
                in 0..3 -> CoverageDifficulty.EASY
                in 4..6 -> CoverageDifficulty.MODERATE
                in 7..8 -> CoverageDifficulty.HARD
                else -> CoverageDifficulty.VERY_HARD
            },
            area = "Area $index",
            group = "Group $index",
            referent = "Referent $index",
            knowledge = "Knowledge $index",
            answer = "Answer $index",
        )
    })

    private class ControlledGeneration(
        private val result: Outcome<StructuredGeneration, AiError>,
    ) {
        val requests = mutableListOf<StructuredGenerationRequest>()

        fun generate(request: StructuredGenerationRequest): Outcome<StructuredGeneration, AiError> {
            requests += request
            return result
        }
    }

    @Test
    fun requestUsesTerraAndIncludesTopicAndFullTenPositionRoute() {
        val generation = ControlledGeneration(Outcome.Success(StructuredGeneration("{" + "\"approved\":true,\"issues\":[]}" , null)))
        val validator = TerraCoverageRouteValidator(generation::generate)

        val result = validator.validate("Historia de Roma", route())

        assertEquals(Unit, assertIs<Outcome.Success<Unit>>(result).value)
        val request = generation.requests.single()
        assertEquals(AiProfile.TERRA, request.profile)
        assertEquals("quiz10_coverage_route_validation", request.schemaName)
        assertContains(request.input, "Tema solicitado: [Historia de Roma]")
        assertContains(request.input, "1. Fácil · Area 0 · Group 0 · Referent 0 · Knowledge 0 · Answer 0")
        assertContains(request.input, "5. Moderado · Area 4 · Group 4 · Referent 4 · Knowledge 4 · Answer 4")
        assertContains(request.input, "8. Difícil · Area 7 · Group 7 · Referent 7 · Knowledge 7 · Answer 7")
        assertContains(request.input, "10. Muy difícil · Area 9 · Group 9 · Referent 9 · Knowledge 9 · Answer 9")
    }

    @Test
    fun schemaIsStrictForApprovedAndIssues() {
        val generation = ControlledGeneration(Outcome.Success(StructuredGeneration("{" + "\"approved\":true,\"issues\":[]}" , null)))
        TerraCoverageRouteValidator(generation::generate).validate("Historia", route())

        val schema = Json.parseToJsonElement(generation.requests.single().schemaJson).jsonObject
        assertEquals(JsonPrimitive("object"), schema["type"])
        assertEquals(JsonArray(listOf(JsonPrimitive("approved"), JsonPrimitive("issues"))), schema["required"])
        assertEquals(JsonPrimitive(false), schema["additionalProperties"])
        val props = schema.getValue("properties").jsonObject
        assertEquals(setOf("approved", "issues"), props.keys)
        assertEquals(JsonPrimitive("boolean"), props.getValue("approved").jsonObject.getValue("type"))
        assertEquals(JsonPrimitive("array"), props.getValue("issues").jsonObject.getValue("type"))
    }

    @Test
    fun approvesValidRouteWhenReviewApproves() {
        val validator = TerraCoverageRouteValidator {
            Outcome.Success(StructuredGeneration("{" + "\"approved\":true,\"issues\":[]}" , null))
        }

        val result = validator.validate("Roma", route())

        assertEquals(Unit, assertIs<Outcome.Success<Unit>>(result).value)
    }

    @Test
    fun rejectsRouteWithReportedIssues() {
        val validator = TerraCoverageRouteValidator {
            Outcome.Success(
                StructuredGeneration(
                    "{" + "\"approved\":false,\"issues\":[\"El referente 6 no pertenece al grupo\"]}",
                    null,
                ),
            )
        }

        val result = validator.validate("Roma", route())

        val error = assertIs<Outcome.Failure<CoverageRouteValidationError>>(result).error
        assertEquals(
            CoverageRouteValidationError.RouteRejected(listOf("El referente 6 no pertenece al grupo")),
            error,
        )
    }

    @Test
    fun rejectsIncompleteContradictoryAndMalformedStructuredResponses() {
        val invalidOutputs = listOf(
            "",
            "{bad",
            "null",
            "[]",
            "{}",
            "{\"approved\":true}",
            "{\"issues\":[]}",
            "{\"approved\":\"true\",\"issues\":[]}",
            "{\"approved\":true,\"issues\":[\"incidencia\"]}",
            "{\"approved\":false,\"issues\":[]}",
            "{\"approved\":false,\"issues\":[1]}",
            "{\"approved\":false,\"issues\":[\"   \"]}",
            "{\"approved\":true,\"issues\":[],\"extra\":1}",
        )

        for (output in invalidOutputs) {
            val validator = TerraCoverageRouteValidator {
                Outcome.Success(StructuredGeneration(output, null))
            }
            val result = validator.validate("Roma", route())
            assertEquals(
                CoverageRouteValidationError.InvalidStructuredResponse,
                assertIs<Outcome.Failure<CoverageRouteValidationError>>(result).error,
            )
        }
    }

    @Test
    fun propagatesAiGenerationErrors() {
        val causes = listOf(
            AiError.InvalidSchemaJson,
            AiError.TransportFailure,
            AiError.HttpFailure(429),
            AiError.InvalidResponseJson,
            AiError.MissingOutputText,
        )

        for (cause in causes) {
            val validator = TerraCoverageRouteValidator {
                Outcome.Failure(cause)
            }
            val result = validator.validate("Roma", route())
            assertEquals(
                CoverageRouteValidationError.GenerationFailed(cause),
                assertIs<Outcome.Failure<CoverageRouteValidationError>>(result).error,
            )
        }
    }
}
