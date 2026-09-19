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
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs

class TerraReplacementQuestionGeneratorTest {
    private val pending = listOf(
        ReplacementQuestionPosition(2, "Física", CoverageDifficulty.EASY),
        ReplacementQuestionPosition(8, "Historia", CoverageDifficulty.HARD),
    )

    private val accepted = listOf(
        AcceptedCoverageQuestion(1, "Accepted question 1", "Accepted answer 1"),
        AcceptedCoverageQuestion(3, "Accepted question 3", "Accepted answer 3"),
    )

    private fun row(
        position: Int,
        question: String,
        answer: String,
        distractor1: String,
        distractor2: String,
        distractor3: String,
    ): JsonObject = buildJsonObject {
        put("position", JsonPrimitive(position))
        put("question", JsonPrimitive(question))
        put("answer", JsonPrimitive(answer))
        put("distractor1", JsonPrimitive(distractor1))
        put("distractor2", JsonPrimitive(distractor2))
        put("distractor3", JsonPrimitive(distractor3))
    }

    private fun response(rows: List<JsonObject>): String =
        buildJsonObject { put("items", JsonArray(rows)) }.toString()

    @Test
    fun requestUsesTerraProfileContainsRealTablesAndStrictSchema() {
        val requests = mutableListOf<StructuredGenerationRequest>()
        val generator = TerraReplacementQuestionGenerator { request ->
            requests += request
            Outcome.Success(
                StructuredGeneration(
                    response(
                        listOf(
                            row(2, "Q2", "A2", "D21", "D22", "D23"),
                            row(8, "Q8", "A8", "D81", "D82", "D83"),
                        ),
                    ),
                    null,
                ),
            )
        }

        generator.generate(pending, accepted)

        val request = requests.single()
        assertEquals(AiProfile.TERRA, request.profile)
        assertEquals("quiz10_replacement_questions", request.schemaName)
        assertContains(request.input, "## POSICIONES POR SUSTITUIR")
        assertContains(request.input, "| 2 | Fácil | Física |")
        assertContains(request.input, "| 8 | Difícil | Historia |")
        assertContains(request.input, "Accepted question 1 -> Accepted answer 1")
        assertContains(request.input, "Accepted question 3 -> Accepted answer 3")
        assertContains(request.input, "| 2 |  |  |  |  |  |")
        assertContains(request.input, "| 8 |  |  |  |  |  |")

        val schema = Json.parseToJsonElement(request.schemaJson).jsonObject
        val array = schema.getValue("properties").jsonObject.getValue("items").jsonObject
        assertEquals(JsonPrimitive(2), array["minItems"])
        assertEquals(JsonPrimitive(2), array["maxItems"])
        val item = array.getValue("items").jsonObject
        val keys = item.getValue("properties").jsonObject.keys
        assertEquals(setOf("position", "question", "answer", "distractor1", "distractor2", "distractor3"), keys)
        assertFalse(keys.contains("area"))
        assertFalse(keys.contains("difficulty"))
    }

    @Test
    fun localValidationMarksInvalidRowsInsteadOfGlobalFailure() {
        val generator = TerraReplacementQuestionGenerator {
            Outcome.Success(
                StructuredGeneration(
                    response(
                        listOf(
                            row(2, "", "A2", "D21", "D22", "D23"),
                            row(8, "Q8", "A8", "A8", "D82", "D83"),
                        ),
                    ),
                    null,
                ),
            )
        }

        val batch = assertIs<Outcome.Success<ReplacementQuestionBatch>>(generator.generate(pending, accepted)).value

        assertEquals(2, batch.results.size)
        assertIs<ReplacementQuestionOutcome.Invalid>(batch.results[0].outcome)
        assertIs<ReplacementQuestionOutcome.Invalid>(batch.results[1].outcome)
    }

    @Test
    fun rejectsQuestionsDuplicatedWithAcceptedOrWithinBatch() {
        val generator = TerraReplacementQuestionGenerator {
            Outcome.Success(
                StructuredGeneration(
                    response(
                        listOf(
                            row(2, " accepted question 1 ", "A2", "D21", "D22", "D23"),
                            row(8, "QX", "A8", "D81", "D82", "D83"),
                        ),
                    ),
                    null,
                ),
            )
        }

        val batch = assertIs<Outcome.Success<ReplacementQuestionBatch>>(generator.generate(pending, accepted)).value
        assertIs<ReplacementQuestionOutcome.Invalid>(batch.results.first().outcome)

        val duplicatedBatch = TerraReplacementQuestionGenerator {
            Outcome.Success(
                StructuredGeneration(
                    response(
                        listOf(
                            row(2, "Q DUP", "A2", "D21", "D22", "D23"),
                            row(8, " q dup ", "A8", "D81", "D82", "D83"),
                        ),
                    ),
                    null,
                ),
            )
        }
        val duplicated = assertIs<Outcome.Success<ReplacementQuestionBatch>>(duplicatedBatch.generate(pending, accepted)).value
        assertIs<ReplacementQuestionOutcome.Valid>(duplicated.results[0].outcome)
        assertIs<ReplacementQuestionOutcome.Invalid>(duplicated.results[1].outcome)
    }

    @Test
    fun rejectsGloballyMalformedResultsAndUnexpectedPositions() {
        val invalidPayloads = listOf(
            "",
            "{bad",
            "null",
            "[]",
            "{}",
            "{\"items\":[]}",
            response(listOf(row(2, "Q2", "A2", "D1", "D2", "D3"))),
            response(
                listOf(
                    row(2, "Q2", "A2", "D1", "D2", "D3"),
                    row(2, "Q8", "A8", "D4", "D5", "D6"),
                ),
            ),
            response(
                listOf(
                    row(2, "Q2", "A2", "D1", "D2", "D3"),
                    row(7, "Q8", "A8", "D4", "D5", "D6"),
                ),
            ),
        )

        for (payload in invalidPayloads) {
            val generator = TerraReplacementQuestionGenerator {
                Outcome.Success(StructuredGeneration(payload, null))
            }
            val result = generator.generate(pending, accepted)
            assertEquals(
                ReplacementQuestionGenerationError.InvalidStructuredResponse,
                assertIs<Outcome.Failure<ReplacementQuestionGenerationError>>(result).error,
            )
        }
    }

    @Test
    fun generationFailurePreservesCause() {
        val causes = listOf(
            AiError.InvalidSchemaJson,
            AiError.TransportFailure,
            AiError.HttpFailure(429),
            AiError.InvalidResponseJson,
            AiError.MissingOutputText,
        )

        for (cause in causes) {
            val generator = TerraReplacementQuestionGenerator { Outcome.Failure(cause) }
            val result = generator.generate(pending, accepted)
            assertEquals(
                ReplacementQuestionGenerationError.GenerationFailed(cause),
                assertIs<Outcome.Failure<ReplacementQuestionGenerationError>>(result).error,
            )
        }
    }
}
