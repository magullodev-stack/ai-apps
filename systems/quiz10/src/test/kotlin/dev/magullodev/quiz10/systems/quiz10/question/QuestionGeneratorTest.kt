package dev.magullodev.quiz10.systems.quiz10.question

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageDifficulty
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRouteItem
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertIs
import kotlin.test.assertSame
import kotlin.test.assertTrue

class QuestionGeneratorTest {
    private val item = CoverageRouteItem(
        difficulty = CoverageDifficulty.EASY,
        area = "History",
        group = "Ancient Rome",
        referent = "Rome",
        knowledge = "Founding year",
        answer = "753 BC",
    )
    private val distractors = listOf(
        "509 BC" to "Marca el inicio de la República, no la fundación.",
        "27 BC" to "Corresponde al inicio del Principado.",
        "476 AD" to "Se relaciona con la caída del Imperio de Occidente.",
    )
    private val correctExplanation = "753 BC es la fecha tradicionalmente aceptada para la fundación de Roma."
    private val validFields = buildJsonObject {
        put("question", "When was Rome founded?")
        put("correctExplanation", correctExplanation)
        put(
            "distractors",
            JsonArray(distractors.map { (text, explanation) ->
                buildJsonObject {
                    put("text", text)
                    put("explanation", explanation)
                }
            }),
        )
    }

    private class ControlledGeneration(
        private val result: Outcome<StructuredGeneration, AiError>,
    ) {
        val requests = mutableListOf<StructuredGenerationRequest>()

        fun generate(request: StructuredGenerationRequest): Outcome<StructuredGeneration, AiError> {
            requests.add(request)
            return result
        }
    }

    private fun generation(text: String = validFields.toString()) =
        ControlledGeneration(Outcome.Success(StructuredGeneration(text, null)))

    private fun changedField(field: String, value: JsonElement): String =
        JsonObject(validFields + (field to value)).toString()

    private fun assertInvalid(text: String, routeItem: CoverageRouteItem = item) {
        val result = QuestionGenerator("test-model", generation(text)::generate).generate(routeItem, 0)

        assertEquals(
            QuestionGenerationError.InvalidGeneratedQuestion,
            assertIs<Outcome.Failure<QuestionGenerationError>>(result).error,
            text,
        )
    }

    @Test
    fun constructorRejectsBlankModelWithoutInvokingGeneration() {
        val generation = generation()
        for (model in listOf("", " ", "\t\n")) {
            assertFailsWith<IllegalArgumentException> { QuestionGenerator(model, generation::generate) }
        }
        assertTrue(generation.requests.isEmpty())
    }

    @Test
    fun rejectsInvalidCorrectOptionIndexBeforeInvokingGeneration() {
        val generation = generation()
        val generator = QuestionGenerator("test-model", generation::generate)
        for (index in listOf(Int.MIN_VALUE, -1, 4, Int.MAX_VALUE)) {
            assertFailsWith<IllegalArgumentException> { generator.generate(item, index) }
        }
        assertTrue(generation.requests.isEmpty())
    }

    @Test
    fun insertsExactAnswerAtEveryValidIndexPreservingDistractorOrder() {
        val itemWithWhitespace = item.copy(answer = " \t753 BC\n ")
        for (index in 0..3) {
            val result = QuestionGenerator("test-model", generation()::generate).generate(itemWithWhitespace, index)

            val question = assertIs<Outcome.Success<QuizQuestion>>(result).value
            assertEquals("When was Rome founded?", question.text)
            val expectedOptions = distractors.map { it.first }.toMutableList().apply { add(index, itemWithWhitespace.answer) }
            val expectedFeedback = distractors.map { it.second }.toMutableList().apply { add(index, correctExplanation) }
            assertEquals(expectedOptions, question.options)
            assertEquals(expectedFeedback[0], question.feedbackFor(0))
            assertEquals(expectedFeedback[1], question.feedbackFor(1))
            assertEquals(expectedFeedback[2], question.feedbackFor(2))
            assertEquals(expectedFeedback[3], question.feedbackFor(3))
            assertEquals(index, question.correctOptionIndex)
        }
    }

    @Test
    fun requestUsesConfiguredModelItemContextAndQuestionSchemaName() {
        val generation = generation()
        QuestionGenerator(model = "configured-model", generateStructured = generation::generate).generate(item, 0)

        val request = generation.requests.single()
        assertEquals("configured-model", request.model)
        assertEquals("quiz10_question", request.schemaName)
        for (field in listOf(
            "area: ${item.area}", "group: ${item.group}", "referent: ${item.referent}",
            "knowledge: ${item.knowledge}", "answer: ${item.answer}",
        )) {
            assertTrue(request.input.contains(field), field)
        }
        for (instruction in listOf(
            "pregunta breve", "exactamente knowledge sobre referent", "contexto necesario de group y area",
            "correctExplanation", "text y explanation", "plausibles pero falsas",
            "breves y comparables en extensión y precisión", "sin anticipar contenidos de preguntas posteriores",
        )) {
            assertTrue(request.input.contains(instruction), instruction)
        }
    }

    @Test
    fun schemaRequiresQuestionCorrectExplanationAndDistractorsWithTextAndExplanation() {
        val generation = generation()
        QuestionGenerator("test-model", generation::generate).generate(item, 0)

        val schema = Json.parseToJsonElement(generation.requests.single().schemaJson).jsonObject
        assertEquals(JsonPrimitive("object"), schema["type"])
        assertEquals(JsonPrimitive(false), schema["additionalProperties"])
        assertEquals(
            setOf("question", "correctExplanation", "distractors"),
            schema.getValue("required").jsonArray.map { it.jsonPrimitive.content }.toSet(),
        )
        val properties = schema.getValue("properties").jsonObject
        assertEquals(setOf("question", "correctExplanation", "distractors"), properties.keys)
        assertEquals(JsonPrimitive("string"), properties.getValue("question").jsonObject["type"])
        assertEquals(JsonPrimitive("string"), properties.getValue("correctExplanation").jsonObject["type"])
        val distractorSchema = properties.getValue("distractors").jsonObject
        assertEquals(JsonPrimitive("array"), distractorSchema["type"])
        assertEquals(JsonPrimitive(3), distractorSchema["minItems"])
        assertEquals(JsonPrimitive(3), distractorSchema["maxItems"])
        val distractorItem = distractorSchema.getValue("items").jsonObject
        assertEquals(JsonPrimitive("object"), distractorItem["type"])
        assertEquals(JsonPrimitive(false), distractorItem["additionalProperties"])
        assertEquals(
            setOf("text", "explanation"),
            distractorItem.getValue("required").jsonArray.map { it.jsonPrimitive.content }.toSet(),
        )
    }

    @Test
    fun generationFailurePreservesEveryAiErrorCause() {
        for (cause in listOf(
            AiError.InvalidSchemaJson, AiError.TransportFailure, AiError.HttpFailure(429),
            AiError.InvalidResponseJson, AiError.MissingOutputText,
        )) {
            val generation = ControlledGeneration(Outcome.Failure(cause))
            val result = QuestionGenerator("test-model", generation::generate).generate(item, 0)

            val error = assertIs<QuestionGenerationError.GenerationFailed>(assertIs<Outcome.Failure<QuestionGenerationError>>(result).error)
            assertSame(cause, error.cause)
        }
    }

    @Test
    fun malformedJsonAndIncorrectRootTypesAreInvalid() {
        for (text in listOf("", "{bad", "null", "[]", "42", "true", "\"question\"", "{}")) {
            assertInvalid(text)
        }
    }

    @Test
    fun missingFieldsAndExtraFieldsAreInvalid() {
        for (field in validFields.keys) {
            assertInvalid(JsonObject(validFields - field).toString())
        }
        assertInvalid(changedField("extra", JsonPrimitive("value")))
    }

    @Test
    fun blankOrNonStringQuestionIsInvalid() {
        for (value in listOf(
            JsonPrimitive(""), JsonPrimitive(" \t\n"), JsonNull, JsonPrimitive(42),
            JsonPrimitive(true), JsonArray(emptyList()), JsonObject(emptyMap()),
        )) {
            assertInvalid(changedField("question", value))
        }
    }

    @Test
    fun blankOrNonStringCorrectExplanationIsInvalid() {
        for (value in listOf(
            JsonPrimitive(""), JsonPrimitive(" \t\n"), JsonNull, JsonPrimitive(42),
            JsonPrimitive(true), JsonArray(emptyList()), JsonObject(emptyMap()),
        )) {
            assertInvalid(changedField("correctExplanation", value))
        }
    }

    @Test
    fun nonArrayOrIncorrectNumberOfDistractorsIsInvalid() {
        for (value in listOf(JsonNull, JsonPrimitive("distractors"), JsonPrimitive(3), JsonObject(emptyMap()))) {
            assertInvalid(changedField("distractors", value))
        }
        for (count in listOf(0, 1, 2, 4)) {
            assertInvalid(
                changedField(
                    "distractors",
                    JsonArray(
                        List(count) {
                            buildJsonObject {
                                put("text", "Distractor $it")
                                put("explanation", "Explanation $it")
                            }
                        },
                    ),
                ),
            )
        }
    }

    @Test
    fun duplicateDistractorsAreInvalidIgnoringCaseAndOuterWhitespace() {
        for (duplicate in listOf("476 AD", "476 ad", " \t476 aD\n ")) {
            assertInvalid(
                changedField(
                    "distractors",
                    JsonArray(
                        listOf(
                            buildJsonObject {
                                put("text", duplicate)
                                put("explanation", "Explanation A")
                            },
                            buildJsonObject {
                                put("text", "27 BC")
                                put("explanation", "Explanation B")
                            },
                            buildJsonObject {
                                put("text", "476 AD")
                                put("explanation", "Explanation C")
                            },
                        ),
                    ),
                ),
            )
        }
    }

    @Test
    fun distractorMatchingAnswerIsInvalidIgnoringCaseAndOuterWhitespace() {
        for (index in distractors.indices) {
            for (answer in listOf("753 BC", "753 bc", " \t753 bC\n ")) {
                val invalid = distractors.toMutableList().apply { this[index] = answer to "Explanation $index" }
                assertInvalid(
                    changedField(
                        "distractors",
                        JsonArray(invalid.map { (text, explanation) ->
                            buildJsonObject {
                                put("text", text)
                                put("explanation", explanation)
                            }
                        }),
                    ),
                    item.copy(answer = " \t753 BC\n "),
                )
            }
        }
    }

    @Test
    fun rejectsInvalidDistractorStructureOrBlankFeedback() {
        val noExplanation = JsonArray(
            listOf(
                buildJsonObject { put("text", "509 BC") },
                buildJsonObject { put("text", "27 BC"); put("explanation", "ok") },
                buildJsonObject { put("text", "476 AD"); put("explanation", "ok") },
            ),
        )
        assertInvalid(changedField("distractors", noExplanation))

        val blankExplanation = JsonArray(
            listOf(
                buildJsonObject { put("text", "509 BC"); put("explanation", " ") },
                buildJsonObject { put("text", "27 BC"); put("explanation", "ok") },
                buildJsonObject { put("text", "476 AD"); put("explanation", "ok") },
            ),
        )
        assertInvalid(changedField("distractors", blankExplanation))
    }

    @Test
    fun trimsGeneratedQuestionAndDistractors() {
        val fields = buildJsonObject {
            put("question", " \tWhen was Rome founded?\n ")
            put("correctExplanation", " \t$correctExplanation\n ")
            put(
                "distractors",
                JsonArray(distractors.map { (text, explanation) ->
                    buildJsonObject {
                        put("text", " \t$text\n ")
                        put("explanation", " \t$explanation\n ")
                    }
                }),
            )
        }
        val result = QuestionGenerator("test-model", generation(fields.toString())::generate).generate(item, 0)

        val question = assertIs<Outcome.Success<QuizQuestion>>(result).value
        assertEquals("When was Rome founded?", question.text)
        assertEquals(listOf(item.answer) + distractors.map { it.first }, question.options)
        assertEquals(correctExplanation, question.feedbackFor(0))
        assertEquals(distractors[0].second, question.feedbackFor(1))
    }

    @Test
    fun parsesQuestionWithDistractorsAndExplanations() {
        val result = QuestionGenerator("test-model", generation()::generate).generate(item, 2)

        val question = assertIs<Outcome.Success<QuizQuestion>>(result).value
        assertEquals("When was Rome founded?", question.text)
        assertEquals(listOf("509 BC", "27 BC", item.answer, "476 AD"), question.options)
        assertEquals(correctExplanation, question.feedbackFor(2))
        assertEquals("Marca el inicio de la República, no la fundación.", question.feedbackFor(0))
        assertEquals("Corresponde al inicio del Principado.", question.feedbackFor(1))
        assertEquals("Se relaciona con la caída del Imperio de Occidente.", question.feedbackFor(3))
    }
}
