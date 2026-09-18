package dev.magullodev.quiz10.systems.quiz10.preparation.luna

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageDifficulty
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRouteItem
import dev.magullodev.quiz10.systems.quiz10.question.QuizQuestion
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertSame
import kotlin.test.assertTrue

class LunaQuizTurnGeneratorTest {
    private val item = CoverageRouteItem(
        difficulty = CoverageDifficulty.MODERATE,
        area = "History",
        group = "Ancient Rome",
        referent = "Cayo Julio Cesar",
        knowledge = "Año del asesinato",
        answer = "44 a. C.",
    )

    private val validTurn = buildJsonObject {
        put("question", "¿En qué año fue asesinado Cayo Julio Cesar?")
        put("correctExplanation", "Las fuentes históricas sitúan su asesinato en el 44 a. C.")
        put(
            "distractors",
            JsonArray(
                listOf(
                    buildJsonObject {
                        put("text", "49 a. C.")
                        put("explanation", "Ese año marca el cruce del Rubicón, no su asesinato.")
                    },
                    buildJsonObject {
                        put("text", "31 a. C.")
                        put("explanation", "Corresponde a Actium, no al magnicidio de Cesar.")
                    },
                    buildJsonObject {
                        put("text", "14 d. C.")
                        put("explanation", "Es el año de la muerte de Augusto.")
                    },
                ),
            ),
        )
    }

    private class ControlledGeneration(
        private val result: Outcome<StructuredGeneration, AiError>,
    ) {
        val requests = mutableListOf<StructuredGenerationRequest>()

        fun generate(request: StructuredGenerationRequest): Outcome<StructuredGeneration, AiError> {
            requests += request
            return result
        }
    }

    private fun response(turn: JsonObject = validTurn): String = turn.toString()

    private fun generation(text: String = response()) =
        ControlledGeneration(Outcome.Success(StructuredGeneration(text, null)))

    @Test
    fun requestUsesLunaProfileAndTurnOnlySchema() {
        val generation = generation()
        val generator = LunaQuizTurnGenerator(generation::generate)

        generator.generate(item, 2)

        val request = generation.requests.single()
        assertEquals(AiProfile.LUNA, request.profile)
        assertEquals("quiz10_luna_turn", request.schemaName)
        assertTrue(request.input.contains("area: History"))
        assertTrue(request.input.contains("group: Ancient Rome"))
        assertTrue(request.input.contains("referent: Cayo Julio Cesar"))
        assertTrue(request.input.contains("knowledge: Año del asesinato"))
        assertTrue(request.input.contains("answer: 44 a. C."))

        val schema = Json.parseToJsonElement(request.schemaJson).jsonObject
        assertEquals(JsonPrimitive(false), schema["additionalProperties"])
        val required = schema.getValue("required").jsonArray.map { it.toString().trim('"') }.toSet()
        assertEquals(setOf("question", "correctExplanation", "distractors"), required)
        assertFalse(request.schemaJson.contains("answer"))
        assertFalse(request.schemaJson.contains("correctOptionIndex"))
    }

    @Test
    fun insertsCanonicalAnswerLocallyAtRequestedIndexAndPreservesDistractorOrder() {
        val question = assertIs<Outcome.Success<QuizQuestion>>(
            LunaQuizTurnGenerator(generation()::generate).generate(item, 1),
        ).value

        assertEquals(1, question.correctOptionIndex)
        assertEquals(item.answer, question.options[1])
        assertEquals("Las fuentes históricas sitúan su asesinato en el 44 a. C.", question.feedbackFor(1))
        assertEquals(
            listOf("49 a. C.", "31 a. C.", "14 d. C."),
            question.options.filterIndexed { index, _ -> index != 1 },
        )
    }

    @Test
    fun rejectsInvalidIndexAndInvalidCoverageItemWithoutCallingAi() {
        val calls = mutableListOf<StructuredGenerationRequest>()
        val generator = LunaQuizTurnGenerator {
            calls += it
            Outcome.Success(StructuredGeneration(response(), null))
        }

        val badIndex = assertIs<Outcome.Failure<QuizTurnGenerationError>>(generator.generate(item, 4)).error
        assertEquals(QuizTurnGenerationError.InvalidCorrectOptionIndex(4), badIndex)

        val badItem = item.copy(answer = " ")
        val badItemError = assertIs<Outcome.Failure<QuizTurnGenerationError>>(generator.generate(badItem, 0)).error
        assertEquals(QuizTurnGenerationError.InvalidCoverageRouteItem, badItemError)
        assertTrue(calls.isEmpty())
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
            val generation = ControlledGeneration(Outcome.Failure(cause))
            val result = LunaQuizTurnGenerator(generation::generate).generate(item, 0)
            val error = assertIs<QuizTurnGenerationError.GenerationFailed>(
                assertIs<Outcome.Failure<QuizTurnGenerationError>>(result).error,
            )
            assertSame(cause, error.cause)
        }
    }

    @Test
    fun rejectsMalformedAndInvalidGeneratedOutput() {
        fun assertInvalid(text: String) {
            val result = LunaQuizTurnGenerator(generation(text)::generate).generate(item, 0)
            assertEquals(
                QuizTurnGenerationError.InvalidGeneratedTurn,
                assertIs<Outcome.Failure<QuizTurnGenerationError>>(result).error,
            )
        }

        for (text in listOf("", "{bad", "null", "[]", "{}")) {
            assertInvalid(text)
        }

        val missingQuestion = JsonObject(validTurn - "question")
        assertInvalid(response(missingQuestion))

        val extraField = JsonObject(validTurn + ("extra" to JsonPrimitive("x")))
        assertInvalid(response(extraField))

        val duplicateDistractors = JsonObject(
            validTurn + (
                "distractors" to JsonArray(
                    listOf(
                        buildJsonObject {
                            put("text", "X")
                            put("explanation", "E1")
                        },
                        buildJsonObject {
                            put("text", " x ")
                            put("explanation", "E2")
                        },
                        buildJsonObject {
                            put("text", "Z")
                            put("explanation", "E3")
                        },
                    ),
                )
                ),
        )
        assertInvalid(response(duplicateDistractors))

        val distractorEqualsAnswer = JsonObject(
            validTurn + (
                "distractors" to JsonArray(
                    listOf(
                        buildJsonObject {
                            put("text", " 44 A. C. ")
                            put("explanation", "E1")
                        },
                        buildJsonObject {
                            put("text", "31 a. C.")
                            put("explanation", "E2")
                        },
                        buildJsonObject {
                            put("text", "14 d. C.")
                            put("explanation", "E3")
                        },
                    ),
                )
                ),
        )
        assertInvalid(response(distractorEqualsAnswer))
    }
}
