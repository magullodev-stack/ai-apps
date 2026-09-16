package dev.magullodev.quiz10.systems.quiz10.coverage

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
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertSame
import kotlin.test.assertTrue

class CoveragePlannerTest {
    private val difficulties = listOf(
        "EASY", "EASY", "EASY", "EASY",
        "MODERATE", "MODERATE", "MODERATE",
        "HARD", "HARD", "VERY_HARD",
    )
    private val textFields = listOf("area", "group", "referent", "knowledge", "answer")
    private val validItems = difficulties.mapIndexed { index, difficulty ->
        buildJsonObject {
            put("difficulty", difficulty)
            put("area", "Area $index")
            put("group", "Group $index")
            put("referent", "Referent $index")
            put("knowledge", "Knowledge $index")
            put("answer", "Answer $index")
        }
    }

    private fun response(items: List<JsonElement> = validItems): String =
        buildJsonObject { put("items", JsonArray(items)) }.toString()

    private fun changedItem(field: String, value: JsonElement): String =
        response(validItems.toMutableList().apply { this[0] = JsonObject(this[0] + (field to value)) })

    private class ControlledGeneration(
        private val result: Outcome<StructuredGeneration, AiError>,
    ) {
        val requests = mutableListOf<StructuredGenerationRequest>()

        fun generate(request: StructuredGenerationRequest): Outcome<StructuredGeneration, AiError> {
            requests.add(request)
            return result
        }
    }

    private fun generation(text: String = response()) =
        ControlledGeneration(Outcome.Success(StructuredGeneration(text, null)))

    private fun assertInvalid(text: String) {
        val result = CoveragePlanner("test-model", generation(text)::generate).plan("Ancient Rome")

        assertEquals(CoveragePlanningError.InvalidGeneratedRoute, assertIs<Outcome.Failure<CoveragePlanningError>>(result).error)
    }

    @Test
    fun constructorRejectsBlankModelWithoutInvokingGeneration() {
        val generation = generation()

        for (model in listOf("", " ", "\t\n")) {
            assertFailsWith<IllegalArgumentException> {
                CoveragePlanner(model, generation::generate)
            }
        }
        assertTrue(generation.requests.isEmpty())
    }

    @Test
    fun validTopicProducesTenItemsWithCanonicalDifficulties() {
        val result = CoveragePlanner("test-model", generation()::generate).plan("Ancient Rome")

        val route = assertIs<Outcome.Success<CoverageRoute>>(result).value
        assertEquals(10, route.size)
        assertEquals(difficulties, route.items.map { it.difficulty.name })
        assertEquals(List(10) { "Referent $it" }, route.items.map { it.referent })
    }

    @Test
    fun requestUsesConfiguredModelTrimmedTopicAndCoverageSchemaName() {
        val generation = generation()
        val planner = CoveragePlanner("configured-model", generation::generate)

        for (topic in listOf(" \tAncient Rome\n ", "  Ancient Rome\n    Art and culture  ")) {
            planner.plan(topic)

            val request = generation.requests.last()
            assertEquals("configured-model", request.model)
            assertTrue(request.input.endsWith(topic.trim()))
            assertFalse(request.input.contains(topic))
            assertEquals("quiz10_coverage_route", request.schemaName)
        }
        assertEquals(2, generation.requests.size)
    }

    @Test
    fun schemaRequiresRootItemsAllFieldsAndKnownDifficultiesWithoutAdditionalProperties() {
        val generation = generation()
        CoveragePlanner("test-model", generation::generate).plan("Ancient Rome")

        val schema = Json.parseToJsonElement(generation.requests.single().schemaJson).jsonObject
        assertEquals(JsonPrimitive("object"), schema["type"])
        assertEquals(JsonArray(listOf(JsonPrimitive("items"))), schema["required"])
        assertEquals(JsonPrimitive(false), schema["additionalProperties"])
        val rootProperties = schema.getValue("properties").jsonObject
        assertEquals(setOf("items"), rootProperties.keys)
        val items = rootProperties.getValue("items").jsonObject
        assertEquals(JsonPrimitive("array"), items["type"])
        assertEquals(JsonPrimitive(10), items["minItems"])
        assertEquals(JsonPrimitive(10), items["maxItems"])
        val item = items.getValue("items").jsonObject
        assertEquals(JsonPrimitive("object"), item["type"])
        assertEquals(JsonPrimitive(false), item["additionalProperties"])
        val expectedFields = (textFields + "difficulty").toSet()
        assertEquals(expectedFields, item.getValue("required").jsonArray.map { it.jsonPrimitive.content }.toSet())
        val properties = item.getValue("properties").jsonObject
        assertEquals(expectedFields, properties.keys)
        for (field in expectedFields) {
            assertEquals(JsonPrimitive("string"), properties.getValue(field).jsonObject["type"])
        }
        assertEquals(
            setOf("EASY", "MODERATE", "HARD", "VERY_HARD"),
            properties.getValue("difficulty").jsonObject.getValue("enum").jsonArray.map { it.jsonPrimitive.content }.toSet(),
        )
    }

    @Test
    fun blankTopicDoesNotInvokeGeneration() {
        val generation = generation()
        val planner = CoveragePlanner("test-model", generation::generate)

        for (topic in listOf("", " ", "\t\n")) {
            val result = planner.plan(topic)
            assertEquals(CoveragePlanningError.BlankTopic, assertIs<Outcome.Failure<CoveragePlanningError>>(result).error)
        }
        assertTrue(generation.requests.isEmpty())
    }

    @Test
    fun generationFailurePreservesCause() {
        val causes = listOf(
            AiError.InvalidSchemaJson, AiError.TransportFailure, AiError.HttpFailure(429),
            AiError.InvalidResponseJson, AiError.MissingOutputText,
        )
        for (cause in causes) {
            val generation = ControlledGeneration(Outcome.Failure(cause))
            val result = CoveragePlanner("test-model", generation::generate).plan("Ancient Rome")

            val error = assertIs<CoveragePlanningError.GenerationFailed>(assertIs<Outcome.Failure<CoveragePlanningError>>(result).error)
            assertSame(cause, error.cause)
        }
    }

    @Test
    fun malformedJsonIsInvalid() {
        assertInvalid("{bad")
    }

    @Test
    fun missingOrIncorrectRootAndItemTypesAreInvalid() {
        for (text in listOf("null", "[]", "{}", """{"items":{}}""", """{"items":null}""")) {
            assertInvalid(text)
        }
        for (value in listOf(JsonNull, JsonPrimitive("item"), JsonArray(emptyList()))) {
            assertInvalid(response(validItems.toMutableList<JsonElement>().apply { this[0] = value }))
        }
    }

    @Test
    fun incorrectLengthIsInvalid() {
        for (items in listOf(emptyList(), validItems.take(9), validItems + validItems.last())) {
            assertInvalid(response(items))
        }
    }

    @Test
    fun incorrectDifficultyDistributionOrOrderIsInvalid() {
        assertInvalid(changedItem("difficulty", JsonPrimitive("MODERATE")))
        assertInvalid(response(validItems.toMutableList().apply {
            this[4] = JsonObject(this[4] + ("difficulty" to JsonPrimitive("EASY")))
        }))
        assertInvalid(response(validItems.toMutableList().apply {
            val first = this[0]
            this[0] = this[4]
            this[4] = first
        }))
    }

    @Test
    fun unknownDifficultyIsInvalid() {
        assertInvalid(changedItem("difficulty", JsonPrimitive("EXPERT")))
    }

    @Test
    fun duplicateReferentIsInvalidIncludingCaseAndOuterWhitespace() {
        for (referent in listOf("Referent 1", " REFERENT 1 ")) {
            assertInvalid(changedItem("referent", JsonPrimitive(referent)))
        }
    }

    @Test
    fun emptyTextFieldsAreInvalid() {
        for (field in textFields) {
            for (value in listOf("", " \t\n")) {
                assertInvalid(changedItem(field, JsonPrimitive(value)))
            }
        }
    }

    @Test
    fun missingFieldsAndNonStringValuesAreInvalid() {
        for (field in textFields + "difficulty") {
            assertInvalid(response(validItems.toMutableList().apply { this[0] = JsonObject(this[0] - field) }))
            for (value in listOf(JsonNull, JsonPrimitive(42), JsonPrimitive(true), JsonObject(emptyMap()), JsonArray(emptyList()))) {
                assertInvalid(changedItem(field, value))
            }
        }
    }

    @Test
    fun additionalPropertiesAreInvalid() {
        assertInvalid(changedItem("extra", JsonPrimitive("value")))
        val root = Json.parseToJsonElement(response()).jsonObject
        assertInvalid(JsonObject(root + ("extra" to JsonPrimitive("value"))).toString())
    }

    @Test
    fun trimsEveryTextFieldBeforeConstructingRoute() {
        val items = validItems.map { item ->
            JsonObject(item.mapValues { (key, value) ->
                if (key in textFields) JsonPrimitive(" \t${value.jsonPrimitive.content}\n ") else value
            })
        }
        val result = CoveragePlanner("test-model", generation(response(items))::generate).plan("Ancient Rome")

        val route = assertIs<Outcome.Success<CoverageRoute>>(result).value
        for ((index, item) in route.items.withIndex()) {
            assertEquals("Area $index", item.area)
            assertEquals("Group $index", item.group)
            assertEquals("Referent $index", item.referent)
            assertEquals("Knowledge $index", item.knowledge)
            assertEquals("Answer $index", item.answer)
        }
    }
}
