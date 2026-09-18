package dev.magullodev.quiz10.systems.quiz10.preparation

import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
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
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertSame
import kotlin.test.assertTrue

class QuizContentPlannerTest {
    private val difficulties = listOf(
        "EASY", "EASY", "EASY", "EASY",
        "MODERATE", "MODERATE", "MODERATE",
        "HARD", "HARD", "VERY_HARD",
    )
    private val topLevelTextFields = listOf(
        "area",
        "group",
        "referent",
        "knowledge",
        "answer",
        "question",
        "correctExplanation",
    )

    private val validItems = difficulties.mapIndexed { index, difficulty ->
        buildJsonObject {
            put("difficulty", difficulty)
            put("area", if (index % 2 == 0) "Area A" else "Area B")
            put("group", if (index % 3 == 0) "Group A" else "Group B")
            put("referent", "Referent $index")
            put("knowledge", "Knowledge $index")
            put("answer", "Answer $index")
            put("question", "Question $index")
            put("correctExplanation", "Correct explanation $index")
            put(
                "distractors",
                JsonArray(
                    listOf(
                        buildJsonObject {
                            put("text", "Distractor A$index")
                            put("explanation", "Explanation A$index")
                        },
                        buildJsonObject {
                            put("text", "Distractor B$index")
                            put("explanation", "Explanation B$index")
                        },
                        buildJsonObject {
                            put("text", "Distractor C$index")
                            put("explanation", "Explanation C$index")
                        },
                    ),
                ),
            )
        }
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

    private fun response(items: List<JsonElement> = validItems): String =
        buildJsonObject { put("items", JsonArray(items)) }.toString()

    private fun generation(text: String = response()) =
        ControlledGeneration(Outcome.Success(StructuredGeneration(text, null)))

    private fun assertInvalid(text: String) {
        val result = QuizContentPlanner(AiProfile.TERRA, generation(text)::generate).plan("Ancient Rome")
        assertEquals(
            QuizContentPlanningError.InvalidGeneratedPlan,
            assertIs<Outcome.Failure<QuizContentPlanningError>>(result).error,
        )
    }

    @Test
    fun blankTopicDoesNotInvokeGeneration() {
        val generation = generation()
        val planner = QuizContentPlanner(AiProfile.TERRA, generation::generate)

        for (topic in listOf("", " ", "\t\n")) {
            val result = planner.plan(topic)
            assertEquals(QuizContentPlanningError.BlankTopic, assertIs<Outcome.Failure<QuizContentPlanningError>>(result).error)
        }
        assertTrue(generation.requests.isEmpty())
    }

    @Test
    fun preparesCompletePlanWithSingleStructuredInvocation() {
        val generation = generation()
        val result = QuizContentPlanner(AiProfile.TERRA, generation::generate).plan("Ancient Rome")

        val plan = assertIs<Outcome.Success<QuizContentPlan>>(result).value
        assertEquals(1, generation.requests.size)
        assertEquals(10, plan.items.size)
        assertEquals(difficulties, plan.items.map { it.difficulty.name })
        assertEquals(3, plan.items.first().distractors.size)
    }

    @Test
    fun requestUsesSelectedProfileTrimmedTopicAndCompleteSchema() {
        val generation = generation()
        val planner = QuizContentPlanner(AiProfile.TERRA, generation::generate)

        planner.plan(" \tAncient Rome\n ")

        val request = generation.requests.single()
        assertEquals(AiProfile.TERRA, request.profile)
        assertTrue(request.input.endsWith("Ancient Rome"))
        assertFalse(request.input.contains(" \tAncient Rome\n "))
        assertEquals("quiz10_content_plan", request.schemaName)

        val schema = Json.parseToJsonElement(request.schemaJson).jsonObject
        assertEquals(JsonPrimitive("object"), schema["type"])
        assertEquals(JsonArray(listOf(JsonPrimitive("items"))), schema["required"])
        assertEquals(JsonPrimitive(false), schema["additionalProperties"])

        val items = schema.getValue("properties").jsonObject.getValue("items").jsonObject
        assertEquals(JsonPrimitive("array"), items["type"])
        assertEquals(JsonPrimitive(10), items["minItems"])
        assertEquals(JsonPrimitive(10), items["maxItems"])

        val item = items.getValue("items").jsonObject
        assertEquals(JsonPrimitive("object"), item["type"])
        assertEquals(JsonPrimitive(false), item["additionalProperties"])
        assertEquals(
            setOf("difficulty") + topLevelTextFields + "distractors",
            item.getValue("required").jsonArray.map { it.jsonPrimitive.content }.toSet(),
        )

        val distractors = item.getValue("properties").jsonObject.getValue("distractors").jsonObject
        assertEquals(JsonPrimitive("array"), distractors["type"])
        assertEquals(JsonPrimitive(3), distractors["minItems"])
        assertEquals(JsonPrimitive(3), distractors["maxItems"])
        val distractorItem = distractors.getValue("items").jsonObject
        assertEquals(JsonPrimitive(false), distractorItem["additionalProperties"])
        assertEquals(
            setOf("text", "explanation"),
            distractorItem.getValue("required").jsonArray.map { it.jsonPrimitive.content }.toSet(),
        )
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
            val result = QuizContentPlanner(AiProfile.TERRA, generation::generate).plan("Ancient Rome")
            val error = assertIs<QuizContentPlanningError.GenerationFailed>(
                assertIs<Outcome.Failure<QuizContentPlanningError>>(result).error,
            )
            assertSame(cause, error.cause)
        }
    }

    @Test
    fun rejectsMalformedOrIncompleteOutput() {
        for (text in listOf("", "{bad", "null", "[]", "{}", "{\"items\":{}}")) {
            assertInvalid(text)
        }

        val missingField = JsonObject(validItems.first() - "question")
        assertInvalid(response(validItems.toMutableList<JsonElement>().apply { this[0] = missingField }))

        val extraField = JsonObject(validItems.first() + ("extra" to JsonPrimitive("x")))
        assertInvalid(response(validItems.toMutableList<JsonElement>().apply { this[0] = extraField }))

        val wrongDifficulty = JsonObject(validItems.first() + ("difficulty" to JsonPrimitive("HARD")))
        assertInvalid(response(validItems.toMutableList<JsonElement>().apply { this[0] = wrongDifficulty }))

        val unknownDifficulty = JsonObject(validItems.first() + ("difficulty" to JsonPrimitive("EXPERT")))
        assertInvalid(response(validItems.toMutableList<JsonElement>().apply { this[0] = unknownDifficulty }))

        val duplicateReferent = JsonObject(validItems.first() + ("referent" to JsonPrimitive(" Referent 1 ")))
        assertInvalid(response(validItems.toMutableList<JsonElement>().apply { this[0] = duplicateReferent }))

        val blankQuestion = JsonObject(validItems.first() + ("question" to JsonPrimitive(" \t\n")))
        assertInvalid(response(validItems.toMutableList<JsonElement>().apply { this[0] = blankQuestion }))

        val twoDistractors = JsonObject(
            validItems.first() +
                (
                    "distractors" to JsonArray(
                        listOf(
                            buildJsonObject { put("text", "A"); put("explanation", "EA") },
                            buildJsonObject { put("text", "B"); put("explanation", "EB") },
                        ),
                    )
                    ),
        )
        assertInvalid(response(validItems.toMutableList<JsonElement>().apply { this[0] = twoDistractors }))

        val distractorEqualsAnswer = JsonObject(
            validItems.first() +
                (
                    "distractors" to JsonArray(
                        listOf(
                            buildJsonObject { put("text", "Answer 0"); put("explanation", "EA") },
                            buildJsonObject { put("text", "B"); put("explanation", "EB") },
                            buildJsonObject { put("text", "C"); put("explanation", "EC") },
                        ),
                    )
                    ),
        )
        assertInvalid(response(validItems.toMutableList<JsonElement>().apply { this[0] = distractorEqualsAnswer }))

        val duplicateDistractors = JsonObject(
            validItems.first() +
                (
                    "distractors" to JsonArray(
                        listOf(
                            buildJsonObject { put("text", "X"); put("explanation", "EA") },
                            buildJsonObject { put("text", "x"); put("explanation", "EB") },
                            buildJsonObject { put("text", "C"); put("explanation", "EC") },
                        ),
                    )
                    ),
        )
        assertInvalid(response(validItems.toMutableList<JsonElement>().apply { this[0] = duplicateDistractors }))

        val noDiversity = validItems.mapIndexed { index, _ ->
            buildJsonObject {
                put("difficulty", difficulties[index])
                put("area", "Single")
                put("group", "Single")
                put("referent", "Referent $index")
                put("knowledge", "Knowledge $index")
                put("answer", "Answer $index")
                put("question", "Question $index")
                put("correctExplanation", "Correct explanation $index")
                put(
                    "distractors",
                    JsonArray(
                        listOf(
                            buildJsonObject { put("text", "D1 $index"); put("explanation", "E1 $index") },
                            buildJsonObject { put("text", "D2 $index"); put("explanation", "E2 $index") },
                            buildJsonObject { put("text", "D3 $index"); put("explanation", "E3 $index") },
                        ),
                    ),
                )
            }
        }
        assertInvalid(response(noDiversity))
    }

    @Test
    fun trimsAllGeneratedTextFields() {
        val paddedItems = validItems.map { item ->
            JsonObject(item.mapValues { (key, value) ->
                when {
                    key in topLevelTextFields -> JsonPrimitive(" \t${value.jsonPrimitive.content}\n ")
                    key != "distractors" -> value
                    else -> {
                        val distractors = value.jsonArray.map { distractor ->
                            val fields = distractor.jsonObject
                            buildJsonObject {
                                put("text", " \t${fields.getValue("text").jsonPrimitive.content}\n ")
                                put("explanation", " \t${fields.getValue("explanation").jsonPrimitive.content}\n ")
                            }
                        }
                        JsonArray(distractors)
                    }
                }
            })
        }

        val result = QuizContentPlanner(AiProfile.TERRA, generation(response(paddedItems))::generate).plan("Ancient Rome")
        val plan = assertIs<Outcome.Success<QuizContentPlan>>(result).value

        for ((index, item) in plan.items.withIndex()) {
            assertEquals(if (index % 2 == 0) "Area A" else "Area B", item.area)
            assertEquals(if (index % 3 == 0) "Group A" else "Group B", item.group)
            assertEquals("Referent $index", item.referent)
            assertEquals("Knowledge $index", item.knowledge)
            assertEquals("Answer $index", item.answer)
            assertEquals("Question $index", item.question)
            assertEquals("Correct explanation $index", item.correctExplanation)
            assertEquals("Distractor A$index", item.distractors[0].text)
            assertEquals("Explanation A$index", item.distractors[0].explanation)
        }
    }
}
