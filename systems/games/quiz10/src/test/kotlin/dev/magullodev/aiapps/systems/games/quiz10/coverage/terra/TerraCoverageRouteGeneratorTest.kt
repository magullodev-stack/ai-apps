package dev.magullodev.aiapps.systems.games.quiz10.coverage.terra

import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.coverage.Quiz10Area
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlan
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlanner
import kotlinx.serialization.json.*
import kotlin.random.Random
import kotlin.test.*

class TerraCoverageRouteGeneratorTest {
    private val topicFields = setOf("area", "group", "referent", "knowledge", "answer")
    private val planFields = setOf("group", "referent", "knowledge", "answer")

    private val topicItems = List(10) { index ->
        buildJsonObject {
            put("area", "History")
            put("group", "Rome")
            put("referent", "Referent $index")
            put("knowledge", "Knowledge $index")
            put("answer", "Answer $index")
        }
    }

    private val planItems = List(10) { index ->
        buildJsonObject {
            put("group", "Group $index")
            put("referent", "Referent $index")
            put("knowledge", "Knowledge $index")
            put("answer", "Answer $index")
        }
    }

    private fun topicResponse(rows: List<JsonElement> = topicItems) =
        buildJsonObject { put("items", JsonArray(rows)) }.toString()

    private fun planResponse(rows: List<JsonElement> = planItems) =
        buildJsonObject { put("items", JsonArray(rows)) }.toString()

    private fun generator(text: String = topicResponse(), capture: (StructuredGenerationRequest) -> Unit = {}) =
        TerraCoverageRouteGenerator { request ->
            capture(request)
            Outcome.Success(StructuredGeneration(text, null))
        }

    private fun sampleRandomPlan(): StandardCoveragePlan =
        StandardCoveragePlanner(Random(17)).random()

    private fun sampleSingleAreaPlan(): StandardCoveragePlan =
        StandardCoveragePlanner(Random(17)).forArea(Quiz10Area.HISTORY)

    private fun assertInvalidTopic(text: String) {
        val result = generator(text).generate("Rome")
        assertEquals(CoverageRouteGenerationError.InvalidGeneratedRoute, assertIs<Outcome.Failure<*>>(result).error)
    }

    private fun assertInvalidPlan(plan: StandardCoveragePlan, text: String) {
        val result = generator(text).generate(plan)
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
            assertEquals(topicFields, item.getValue("properties").jsonObject.keys)
            assertEquals(topicFields, item.getValue("required").jsonArray.map { it.jsonPrimitive.content }.toSet())
            item.getValue("properties").jsonObject.values.forEach {
                assertEquals(JsonPrimitive("string"), it.jsonObject["type"])
            }
        }).generate("Rome")
    }

    @Test
    fun planRequestContainsTenRealRowsForRandomAndSingleAreaPlans() {
        for (plan in listOf(sampleRandomPlan(), sampleSingleAreaPlan())) {
            val requests = mutableListOf<StructuredGenerationRequest>()
            generator(text = planResponse(), capture = { requests.add(it) }).generate(plan)
            val request = requests.single()
            assertEquals(AiProfile.TERRA, request.profile)
            assertContains(request.input, "Completa la ruta de cobertura.")
            assertContains(
                request.input,
                "| N.º | Dificultad | Área | Grupo | Referente | Conocimiento | Respuesta |",
            )

            plan.positions.forEach { position ->
                val difficulty = when (position.difficulty) {
                    CoverageDifficulty.EASY -> "Fácil"
                    CoverageDifficulty.MODERATE -> "Moderado"
                    CoverageDifficulty.HARD -> "Difícil"
                    CoverageDifficulty.VERY_HARD -> "Muy difícil"
                }
                assertContains(
                    request.input,
                    "| ${position.position} | $difficulty | ${position.area.label} |  |  |  |  |",
                )
            }
            assertFalse(request.input.contains("[ÁREA 1]"))
        }
    }

    @Test
    fun planSchemaRequiresExactlyFourFieldsPerItemAndNoAreaOrDifficulty() {
        val plan = sampleRandomPlan()
        generator(text = planResponse(), capture = { request ->
            assertEquals("quiz10_coverage_route_from_plan", request.schemaName)
            for (forbidden in listOf("area", "difficulty", "question", "distractors")) {
                assertFalse(request.schemaJson.contains("\"$forbidden\""))
            }
            val root = Json.parseToJsonElement(request.schemaJson).jsonObject
            assertEquals(JsonPrimitive(false), root["additionalProperties"])
            assertEquals(setOf("items"), root.getValue("properties").jsonObject.keys)
            val array = root.getValue("properties").jsonObject.getValue("items").jsonObject
            assertEquals(JsonPrimitive("array"), array["type"])
            assertEquals(JsonPrimitive(10), array["minItems"])
            assertEquals(JsonPrimitive(10), array["maxItems"])
            val item = array.getValue("items").jsonObject
            assertEquals(JsonPrimitive(false), item["additionalProperties"])
            assertEquals(planFields, item.getValue("properties").jsonObject.keys)
            assertEquals(planFields, item.getValue("required").jsonArray.map { it.jsonPrimitive.content }.toSet())
        }).generate(plan)
    }

    @Test
    fun returnsCanonicalCoverageRouteWithTenPositions() {
        val route = assertIs<Outcome.Success<CoverageRoute>>(generator().generate("Rome")).value
        assertEquals(10, route.items.size)
        assertEquals(List(10) { "Referent $it" }, route.items.map { it.referent })
        assertEquals(setOf("History"), route.items.map { it.area }.toSet())
        assertEquals(setOf("Rome"), route.items.map { it.group }.toSet())
        assertEquals("Knowledge 0", route.items.first().knowledge)
        assertEquals("Answer 0", route.items.first().answer)
        for (count in listOf(0, 1, 9, 11, 12)) {
            assertInvalidTopic(topicResponse(List(count) { index ->
                JsonObject(topicItems.first() + ("referent" to JsonPrimitive("Referent $index")))
            }))
        }
    }

    @Test
    fun planResultKeepsAreasAndDifficultiesFromPlanOnly() {
        val plan = sampleRandomPlan()
        val route = assertIs<Outcome.Success<CoverageRoute>>(
            generator(text = planResponse()).generate(plan),
        ).value

        assertEquals(10, route.items.size)
        assertEquals(plan.positions.map { it.area.label }, route.items.map { it.area })
        assertEquals(plan.positions.map { it.difficulty }, route.items.map { it.difficulty })
        assertEquals(planItems.map { it.jsonObject.getValue("group").jsonPrimitive.content }, route.items.map { it.group })
    }

    @Test
    fun rejectsDuplicateReferentsAfterTrimAndCaseNormalization() {
        for (duplicate in listOf("Referent 0", "REFERENT 0", " \tReFeReNt 0\n ")) {
            assertInvalidTopic(topicResponse(topicItems.toMutableList().apply {
                this[9] = JsonObject(this[9] + ("referent" to JsonPrimitive(duplicate)))
            }))
        }
    }

    @Test
    fun planModeRejectsMalformedRowsAndDuplicateReferents() {
        val plan = sampleRandomPlan()
        for (count in listOf(0, 1, 9, 11, 12)) {
            assertInvalidPlan(plan, planResponse(List(count) { index ->
                JsonObject(planItems.first() + ("referent" to JsonPrimitive("Referent $index")))
            }))
        }

        for (field in planFields) {
            for (value in listOf(JsonPrimitive(""), JsonPrimitive(" \t\n"), JsonNull, JsonPrimitive(1), JsonPrimitive(false))) {
                assertInvalidPlan(plan, planResponse(planItems.toMutableList().apply {
                    this[0] = JsonObject(this[0] + (field to value))
                }))
            }
            assertInvalidPlan(plan, planResponse(planItems.toMutableList().apply { this[0] = JsonObject(this[0] - field) }))
        }

        for (field in listOf("area", "difficulty", "question", "extra")) {
            assertInvalidPlan(plan, planResponse(planItems.toMutableList().apply {
                this[0] = JsonObject(this[0] + (field to JsonPrimitive("unexpected")))
            }))
        }

        for (text in listOf("", "{bad", "null", "[]", "{}", "{\"items\":{}}", "{\"items\":[null]}")) {
            assertInvalidPlan(plan, text)
        }

        assertInvalidPlan(
            plan,
            planResponse(planItems.toMutableList().apply {
                this[9] = JsonObject(this[9] + ("referent" to JsonPrimitive(" \tReFeReNt 0\n ")))
            }),
        )
    }

    @Test
    fun rejectsBlankMissingExtraAndNonStringFields() {
        for (field in topicFields) {
            for (value in listOf(JsonPrimitive(""), JsonPrimitive(" \t\n"), JsonNull, JsonPrimitive(1), JsonPrimitive(false))) {
                assertInvalidTopic(topicResponse(topicItems.toMutableList().apply {
                    this[0] = JsonObject(this[0] + (field to value))
                }))
            }
            assertInvalidTopic(topicResponse(topicItems.toMutableList().apply { this[0] = JsonObject(this[0] - field) }))
        }
        for (field in listOf("difficulty", "question", "distractors", "explanation", "correctExplanation", "extra")) {
            assertInvalidTopic(topicResponse(topicItems.toMutableList().apply {
                this[0] = JsonObject(this[0] + (field to JsonPrimitive("unexpected")))
            }))
        }
        for (text in listOf("", "{bad", "null", "[]", "{}", "{\"items\":{}}", "{\"items\":[null]}")) {
            assertInvalidTopic(text)
        }
        assertInvalidTopic(JsonObject(Json.parseToJsonElement(topicResponse()).jsonObject + ("extra" to JsonNull)).toString())
    }

    @Test
    fun assignsDifficultyByPositionWithFourThreeTwoOneDistribution() {
        val route = assertIs<Outcome.Success<CoverageRoute>>(generator().generate("Rome")).value
        assertEquals(
            List(4) { CoverageDifficulty.EASY } + List(3) { CoverageDifficulty.MODERATE } +
                List(2) { CoverageDifficulty.HARD } + CoverageDifficulty.VERY_HARD,
            route.items.map { it.difficulty },
        )
    }

    @Test
    fun preservesCanonicalRouteInvariants() {
        val valid = assertIs<Outcome.Success<CoverageRoute>>(generator().generate("Rome")).value.items
        assertFailsWith<IllegalArgumentException> { CoverageRoute.of(emptyList()) }
        assertFailsWith<IllegalArgumentException> {
            CoverageRoute.of(
                listOf(
                    valid[0].copy(difficulty = CoverageDifficulty.MODERATE),
                    valid[1].copy(difficulty = CoverageDifficulty.EASY),
                ) + valid.drop(2),
            )
        }
        assertFailsWith<IllegalArgumentException> { CoverageRoute.of(List(10) { valid.first() }) }
        val mutable = valid.toMutableList()
        val route = CoverageRoute.of(mutable)
        mutable.clear()
        assertEquals(valid, route.items)
        assertFailsWith<UnsupportedOperationException> { (route.items as MutableList).clear() }
    }

    @Test
    fun blankTopicDoesNotInvokeGenerationAndFailuresPreserveCause() {
        val generator = TerraCoverageRouteGenerator { error("Must not generate") }
        for (topic in listOf("", " \t\n")) {
            assertEquals(Outcome.Failure(CoverageRouteGenerationError.BlankTopic), generator.generate(topic))
        }
        val cause = AiError.HttpFailure(429)
        val failing = TerraCoverageRouteGenerator { Outcome.Failure(cause) }
        assertEquals(Outcome.Failure(CoverageRouteGenerationError.GenerationFailed(cause)), failing.generate("Rome"))
        assertEquals(Outcome.Failure(CoverageRouteGenerationError.GenerationFailed(cause)), failing.generate(sampleRandomPlan()))
    }
}
