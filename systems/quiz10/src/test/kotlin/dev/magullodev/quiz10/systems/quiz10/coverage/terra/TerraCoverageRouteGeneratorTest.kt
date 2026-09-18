package dev.magullodev.quiz10.systems.quiz10.coverage.terra

import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageDifficulty
import kotlinx.serialization.json.*
import kotlin.test.*

class TerraCoverageRouteGeneratorTest {
    private val fields = setOf("emoji", "area", "group", "referent", "knowledge", "answer")
    private val items = List(10) { index ->
        buildJsonObject {
            put("emoji", "🏛️")
            put("area", "History")
            put("group", "Rome")
            put("referent", "Referent $index")
            put("knowledge", "Knowledge $index")
            put("answer", "Answer $index")
        }
    }

    private fun response(rows: List<JsonElement> = items) =
        buildJsonObject { put("items", JsonArray(rows)) }.toString()

    private fun generator(text: String = response(), capture: (StructuredGenerationRequest) -> Unit = {}) =
        TerraCoverageRouteGenerator(AiProfile.TERRA) { request ->
            capture(request)
            Outcome.Success(StructuredGeneration(text, null))
        }

    private fun assertInvalid(text: String) {
        val result = generator(text).generate("Rome")
        assertEquals(CoverageRouteGenerationError.InvalidGeneratedRoute, assertIs<Outcome.Failure<*>>(result).error)
    }

    @Test
    fun requestIsExactlyTheSpecifiedPromptWithOnlyTopicSubstituted() {
        val template = checkNotNull(javaClass.getResource("/coverage/terra-prompt.txt")).readText()
        for (topic in listOf("Roma antigua", " \tRoma\n [TEMA] [  ] \$topic ")) {
            val requests = mutableListOf<StructuredGenerationRequest>()
            generator(capture = { requests.add(it) }).generate(topic)
            val request = requests.single()
            assertEquals(AiProfile.TERRA, request.profile)
            assertEquals(template.replaceFirst("Tema: [  ]", "Tema: [$topic]"), request.input)
        }
    }

    @Test
    fun schemaHasExactlySixFieldsAndTenOrderedItems() {
        generator(capture = { request ->
            assertEquals("quiz10_coverage_route", request.schemaName)
            for (forbidden in listOf("difficulty", "question", "distractors", "explanation", "correctExplanation")) {
                assertFalse(request.schemaJson.contains(forbidden))
            }
            val root = Json.parseToJsonElement(request.schemaJson).jsonObject
            assertEquals(JsonPrimitive(false), root["additionalProperties"])
            assertEquals(setOf("items"), root.getValue("properties").jsonObject.keys)
            assertEquals(JsonArray(listOf(JsonPrimitive("items"))), root.getValue("required").jsonArray)
            val array = root.getValue("properties").jsonObject.getValue("items").jsonObject
            assertEquals(JsonPrimitive("array"), array["type"])
            assertEquals(JsonPrimitive(10), array["minItems"])
            assertEquals(JsonPrimitive(10), array["maxItems"])
            val item = array.getValue("items").jsonObject
            assertEquals(JsonPrimitive(false), item["additionalProperties"])
            assertEquals(fields, item.getValue("properties").jsonObject.keys)
            assertEquals(fields, item.getValue("required").jsonArray.map { it.jsonPrimitive.content }.toSet())
            item.getValue("properties").jsonObject.values.forEach {
                assertEquals(JsonPrimitive("string"), it.jsonObject["type"])
            }
        }).generate("Rome")
    }

    @Test
    fun acceptsTenRowsInOrderIncludingRepeatedAreasAndGroups() {
        val route = assertIs<Outcome.Success<CoverageRoute>>(generator().generate("Rome")).value
        assertEquals(10, route.items.size)
        assertEquals(List(10) { "Referent $it" }, route.items.map { it.referent })
        assertEquals(setOf("History"), route.items.map { it.area }.toSet())
        assertEquals(setOf("Rome"), route.items.map { it.group }.toSet())
        assertEquals("🏛️", route.items.first().emoji)
        assertEquals("Knowledge 0", route.items.first().knowledge)
        assertEquals("Answer 0", route.items.first().answer)
        for (count in listOf(0, 1, 9, 11, 12)) {
            assertInvalid(response(List(count) { index ->
                JsonObject(items.first() + ("referent" to JsonPrimitive("Referent $index")))
            }))
        }
    }

    @Test
    fun rejectsDuplicateReferentsAfterTrimAndCaseNormalization() {
        for (duplicate in listOf("Referent 0", "REFERENT 0", " \tReFeReNt 0\n ")) {
            assertInvalid(response(items.toMutableList().apply {
                this[9] = JsonObject(this[9] + ("referent" to JsonPrimitive(duplicate)))
            }))
        }
    }

    @Test
    fun rejectsBlankMissingExtraAndNonStringFields() {
        for (field in fields) {
            for (value in listOf(JsonPrimitive(""), JsonPrimitive(" \t\n"), JsonNull, JsonPrimitive(1), JsonPrimitive(false))) {
                assertInvalid(response(items.toMutableList().apply {
                    this[0] = JsonObject(this[0] + (field to value))
                }))
            }
            assertInvalid(response(items.toMutableList().apply { this[0] = JsonObject(this[0] - field) }))
        }
        for (field in listOf("difficulty", "question", "distractors", "explanation", "correctExplanation", "extra")) {
            assertInvalid(response(items.toMutableList().apply {
                this[0] = JsonObject(this[0] + (field to JsonPrimitive("unexpected")))
            }))
        }
        for (text in listOf("", "{bad", "null", "[]", "{}", "{\"items\":{}}", "{\"items\":[null]}")) {
            assertInvalid(text)
        }
        assertInvalid(JsonObject(Json.parseToJsonElement(response()).jsonObject + ("extra" to JsonNull)).toString())
    }

    @Test
    fun derivesDifficultyFromOneBasedRowWithFourThreeTwoOneDistribution() {
        val route = assertIs<Outcome.Success<CoverageRoute>>(generator().generate("Rome")).value
        assertEquals(
            List(4) { CoverageDifficulty.EASY } + List(3) { CoverageDifficulty.MODERATE } +
                List(2) { CoverageDifficulty.HARD } + CoverageDifficulty.VERY_HARD,
            (1..10).map(route::difficultyForRow),
        )
        for (row in listOf(-1, 0, 11)) {
            assertFailsWith<IllegalArgumentException> { route.difficultyForRow(row) }
        }
    }

    @Test
    fun domainValidatesRowsAndProtectsSnapshot() {
        val valid = assertIs<Outcome.Success<CoverageRoute>>(generator().generate("Rome")).value.items
        assertFailsWith<IllegalArgumentException> { valid.first().copy(emoji = " ") }
        assertFailsWith<IllegalArgumentException> { CoverageRoute.of(valid.take(9)) }
        assertFailsWith<IllegalArgumentException> { CoverageRoute.of(List(10) { valid.first() }) }
        val mutable = valid.toMutableList()
        val route = CoverageRoute.of(mutable)
        mutable.clear()
        assertEquals(valid, route.items)
        assertFailsWith<UnsupportedOperationException> { (route.items as MutableList).clear() }
    }

    @Test
    fun blankTopicDoesNotInvokeGenerationAndFailuresPreserveCause() {
        val generator = TerraCoverageRouteGenerator(AiProfile.TERRA) { error("Must not generate") }
        for (topic in listOf("", " \t\n")) {
            assertEquals(Outcome.Failure(CoverageRouteGenerationError.BlankTopic), generator.generate(topic))
        }
        val cause = AiError.HttpFailure(429)
        val failing = TerraCoverageRouteGenerator(AiProfile.TERRA) { Outcome.Failure(cause) }
        assertEquals(Outcome.Failure(CoverageRouteGenerationError.GenerationFailed(cause)), failing.generate("Rome"))
    }
}
