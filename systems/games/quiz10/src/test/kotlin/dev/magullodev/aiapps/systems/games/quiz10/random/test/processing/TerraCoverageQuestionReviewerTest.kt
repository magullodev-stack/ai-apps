package dev.magullodev.aiapps.systems.games.quiz10.random.test.processing

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
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs

class TerraCoverageQuestionReviewerTest {
    private fun route(): CoverageRoute = CoverageRoute.of(List(10) { index ->
        CoverageRouteItem(
            difficulty = when (index) {
                in 0..3 -> CoverageDifficulty.EASY
                in 4..6 -> CoverageDifficulty.MODERATE
                in 7..8 -> CoverageDifficulty.HARD
                else -> CoverageDifficulty.VERY_HARD
            },
            area = if (index % 2 == 0) "Historia" else "Física",
            group = "Group $index",
            referent = "Referent $index",
            knowledge = "Knowledge $index",
            answer = "Answer $index",
        )
    })

    private fun validRow(index: Int): JsonObject = buildJsonObject {
        put("valid", JsonPrimitive(true))
        put("issue", JsonPrimitive(""))
        put("question", JsonPrimitive("Question $index"))
        put("answer", JsonPrimitive("Answer $index"))
        put("distractor1", JsonPrimitive("Distractor ${index}A"))
        put("distractor2", JsonPrimitive("Distractor ${index}B"))
        put("distractor3", JsonPrimitive("Distractor ${index}C"))
    }

    private fun invalidRow(issue: String): JsonObject = buildJsonObject {
        put("valid", JsonPrimitive(false))
        put("issue", JsonPrimitive(issue))
        put("question", JsonPrimitive(""))
        put("answer", JsonPrimitive(""))
        put("distractor1", JsonPrimitive(""))
        put("distractor2", JsonPrimitive(""))
        put("distractor3", JsonPrimitive(""))
    }

    private fun response(rows: List<JsonObject>): String =
        buildJsonObject { put("items", JsonArray(rows)) }.toString()

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
    fun promptContainsTenRowsInOriginalOrder() {
        val generation = ControlledGeneration(
            Outcome.Success(StructuredGeneration(response(List(10) { validRow(it) }), null)),
        )
        val reviewer = TerraCoverageQuestionReviewer(generation::generate)

        reviewer.review(route())

        val request = generation.requests.single()
        assertContains(request.input, "## RUTA DE COBERTURA")
        assertContains(request.input, "| N.º | Dificultad | Área | Grupo | Referente | Conocimiento | Respuesta |")
        assertContains(request.input, "| 1 | Fácil | Historia | Group 0 | Referent 0 | Knowledge 0 | Answer 0 |")
        assertContains(request.input, "| 2 | Fácil | Física | Group 1 | Referent 1 | Knowledge 1 | Answer 1 |")
        assertContains(request.input, "| 8 | Difícil | Física | Group 7 | Referent 7 | Knowledge 7 | Answer 7 |")
        assertContains(request.input, "| 10 | Muy difícil | Física | Group 9 | Referent 9 | Knowledge 9 | Answer 9 |")
    }

    @Test
    fun requestUsesTerraProfileAndStrictTenItemSchema() {
        val generation = ControlledGeneration(
            Outcome.Success(StructuredGeneration(response(List(10) { validRow(it) }), null)),
        )
        val reviewer = TerraCoverageQuestionReviewer(generation::generate)

        reviewer.review(route())

        val request = generation.requests.single()
        assertEquals(AiProfile.TERRA, request.profile)
        assertEquals("quiz10_coverage_question_review", request.schemaName)

        val root = Json.parseToJsonElement(request.schemaJson).jsonObject
        assertEquals(JsonPrimitive(false), root["additionalProperties"])
        val array = root.getValue("properties").jsonObject.getValue("items").jsonObject
        assertEquals(JsonPrimitive(10), array["minItems"])
        assertEquals(JsonPrimitive(10), array["maxItems"])
        val item = array.getValue("items").jsonObject
        assertEquals(JsonPrimitive(false), item["additionalProperties"])
        val keys = item.getValue("properties").jsonObject.keys
        assertEquals(
            setOf("valid", "issue", "question", "answer", "distractor1", "distractor2", "distractor3"),
            keys,
        )
        assertFalse(keys.contains("area"))
        assertFalse(keys.contains("difficulty"))
    }

    @Test
    fun acceptsReplacementWithNewAnswerInTheSameResponse() {
        val rows = List(10) { validRow(it) }.toMutableList()
        rows[3] = JsonObject(rows[3] + mapOf(
            "valid" to JsonPrimitive(false),
            "issue" to JsonPrimitive("Respuesta original incorrecta"),
            "answer" to JsonPrimitive("Replacement answer"),
        ))
        val reviewer = TerraCoverageQuestionReviewer {
            assertContains(it.input, "conserva literalmente la respuesta original")
            assertContains(it.input, "valid=false")
            Outcome.Success(StructuredGeneration(response(rows), null))
        }
        val review = assertIs<Outcome.Success<CoverageQuestionReview>>(reviewer.review(route())).value
        val replacement = assertIs<CoverageQuestionReviewPosition.Replaced>(review.positions[3])
        assertEquals("Replacement answer", replacement.answer)
        assertEquals("Respuesta original incorrecta", replacement.issue)
        assertEquals(10, review.positions.size)
    }

    @Test
    fun rejectsMalformedOrDuplicateReplacementsLocally() {
        for (changes in listOf(
            mapOf("issue" to JsonPrimitive("")),
            mapOf("question" to JsonPrimitive("Question 0")),
            mapOf("distractor1" to JsonPrimitive("Answer 3")),
            mapOf("distractor1" to JsonPrimitive("")),
            mapOf("distractor1" to JsonPrimitive("Distractor 3B")),
        )) {
            val rows = List(10) { validRow(it) }.toMutableList()
            rows[3] = JsonObject(rows[3] + mapOf(
                "valid" to JsonPrimitive(false), "issue" to JsonPrimitive("Invalid original"),
            ) + changes)
            val reviewer = TerraCoverageQuestionReviewer {
                Outcome.Success(StructuredGeneration(response(rows), null))
            }
            val review = assertIs<Outcome.Success<CoverageQuestionReview>>(reviewer.review(route())).value
            assertIs<CoverageQuestionReviewPosition.Invalid>(review.positions[3])
        }
    }

    @Test
    fun acceptsTenValidRows() {
        val reviewer = TerraCoverageQuestionReviewer {
            Outcome.Success(StructuredGeneration(response(List(10) { validRow(it) }), null))
        }

        val result = reviewer.review(route())

        val review = assertIs<Outcome.Success<CoverageQuestionReview>>(result).value
        assertEquals(10, review.positions.size)
        review.positions.forEachIndexed { index, position ->
            val valid = assertIs<CoverageQuestionReviewPosition.Valid>(position)
            assertEquals("Question $index", valid.question)
            assertEquals("Answer $index", valid.answer)
            assertEquals(3, valid.distractors.size)
        }
    }

    @Test
    fun supportsMixedValidAndInvalidRowsWithoutGlobalFailure() {
        val rows = List(10) { index -> if (index == 3) invalidRow("Conocimiento repetido") else validRow(index) }
        val reviewer = TerraCoverageQuestionReviewer {
            Outcome.Success(StructuredGeneration(response(rows), null))
        }

        val result = reviewer.review(route())

        val review = assertIs<Outcome.Success<CoverageQuestionReview>>(result).value
        assertIs<CoverageQuestionReviewPosition.Invalid>(review.positions[3])
        assertIs<CoverageQuestionReviewPosition.Valid>(review.positions[0])
        assertIs<CoverageQuestionReviewPosition.Valid>(review.positions[9])
    }

    @Test
    fun convertsLocallyInvalidDeclaredValidRowsIntoInvalidPositions() {
        val rows = List(10) { validRow(it) }.toMutableList()
        rows[0] = JsonObject(rows[0] + ("answer" to JsonPrimitive("Different answer")))
        rows[1] = JsonObject(rows[1] + ("question" to JsonPrimitive("   ")))
        rows[2] = JsonObject(rows[2] + ("distractor3" to JsonPrimitive("Distractor 2A")))
        rows[3] = JsonObject(rows[3] + ("distractor2" to JsonPrimitive(" answer 3 ")))

        val reviewer = TerraCoverageQuestionReviewer {
            Outcome.Success(StructuredGeneration(response(rows), null))
        }

        val review = assertIs<Outcome.Success<CoverageQuestionReview>>(reviewer.review(route())).value

        assertIs<CoverageQuestionReviewPosition.Invalid>(review.positions[0])
        assertIs<CoverageQuestionReviewPosition.Invalid>(review.positions[1])
        assertIs<CoverageQuestionReviewPosition.Invalid>(review.positions[2])
        assertIs<CoverageQuestionReviewPosition.Invalid>(review.positions[3])
        assertIs<CoverageQuestionReviewPosition.Valid>(review.positions[4])
    }

    @Test
    fun marksLaterDuplicateQuestionStatementsAsInvalid() {
        val rows = List(10) { validRow(it) }.toMutableList()
        rows[1] = JsonObject(rows[1] + ("question" to JsonPrimitive("  QUESTION 0  ")))

        val reviewer = TerraCoverageQuestionReviewer {
            Outcome.Success(StructuredGeneration(response(rows), null))
        }

        val review = assertIs<Outcome.Success<CoverageQuestionReview>>(reviewer.review(route())).value

        assertIs<CoverageQuestionReviewPosition.Valid>(review.positions[0])
        assertIs<CoverageQuestionReviewPosition.Invalid>(review.positions[1])
    }

    @Test
    fun rejectsGloballyMalformedOrWrongSizedResponsesWithTypedError() {
        val invalidPayloads = listOf(
            "",
            "{bad",
            "null",
            "[]",
            "{}",
            "{\"items\":[]}",
            response(List(9) { validRow(it) }),
            response(List(11) { validRow(if (it > 9) 9 else it) }),
            buildJsonObject {
                put(
                    "items",
                    JsonArray(
                        List(10) { index ->
                            if (index == 0) {
                                buildJsonObject {
                                    put("valid", JsonPrimitive(true))
                                    put("issue", JsonPrimitive(""))
                                    put("question", JsonPrimitive("Q"))
                                    put("answer", JsonPrimitive("A"))
                                    put("distractor1", JsonPrimitive("D1"))
                                    put("distractor2", JsonPrimitive("D2"))
                                }
                            } else {
                                validRow(index)
                            }
                        },
                    ),
                )
            }.toString(),
        )

        for (payload in invalidPayloads) {
            val reviewer = TerraCoverageQuestionReviewer {
                Outcome.Success(StructuredGeneration(payload, null))
            }
            val result = reviewer.review(route())
            assertEquals(
                CoverageQuestionReviewError.InvalidStructuredResponse,
                assertIs<Outcome.Failure<CoverageQuestionReviewError>>(result).error,
            )
        }
    }

    @Test
    fun generationFailurePreservesCause() {
        val causes = listOf(
            AiError.InvalidSchemaJson,
            AiError.TransportFailure,
            AiError.HttpFailure(503),
            AiError.InvalidResponseJson,
            AiError.MissingOutputText,
        )

        for (cause in causes) {
            val reviewer = TerraCoverageQuestionReviewer {
                Outcome.Failure(cause)
            }
            val result = reviewer.review(route())
            assertEquals(
                CoverageQuestionReviewError.GenerationFailed(cause),
                assertIs<Outcome.Failure<CoverageQuestionReviewError>>(result).error,
            )
        }
    }
}
