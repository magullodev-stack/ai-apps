package dev.magullodev.aiapps.apps.quiz10.web

import dev.magullodev.aiapps.core.ai.*
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.UrlConnectionHttpTransport
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlanner
import dev.magullodev.aiapps.systems.games.quiz10.preparation.PreparedQuiz
import dev.magullodev.aiapps.systems.games.quiz10.session.Quiz10Flow
import dev.magullodev.aiapps.systems.games.quiz10.session.Quiz10FlowState
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import org.junit.jupiter.api.Assumptions.assumeTrue
import kotlin.test.*

class RandomTestPreparationTest {
    private fun coverage() = (1..10).joinToString(prefix = "{\"items\":[", postfix = "]}") {
        """{"group":"G$it","referent":"R$it","knowledge":"K$it","answer":"A$it"}"""
    }

    private fun review(replaced: Boolean, unresolved: Boolean = false) =
        (1..10).joinToString(prefix = "{\"items\":[", postfix = "]}") {
            val replacement = replaced && it == 2
            val question = if (replacement && unresolved) "" else "Q$it"
            val answer = if (replacement) "Replacement answer" else "A$it"
            val issue = if (replacement) "Original answer incorrect" else ""
            """{"valid":${!replacement},"issue":"$issue","question":"$question","answer":"$answer","distractor1":"X$it","distractor2":"Y$it","distractor3":"Z$it"}"""
        }

    @Test
    fun webPlaysAllTenQuestionsWithExactlyTwoTerraCallsIncludingInlineReplacement() {
        for (replaced in listOf(false, true)) {
            val requests = mutableListOf<StructuredGenerationRequest>()
            val audits = mutableListOf<AiUsageAuditEvent>()
            val monitor = object : AiUsageMonitor {
                override fun recordCall(event: AiUsageCallEvent) = Unit
                override fun recordMetric(event: AiUsageMetricEvent) = Unit
                override fun recordAudit(event: AiUsageAuditEvent) { audits += event }
            }
            val preparer = createQuizPreparer(usageMonitor = monitor) { request ->
                requests += request
                Outcome.Success(StructuredGeneration(when (requests.size) {
                    1 -> coverage()
                    2 -> review(replaced)
                    else -> error("Unexpected third AI call")
                }, null))
            }
            Quiz10WebServer(preparer::prepare, { _, _ -> error("Prebuilt quiz must not call Luna") },
                host = "127.0.0.1", port = 0).use { server ->
                val base = "http://127.0.0.1:${server.start()}"
                val client = HttpClient.newHttpClient()
                fun post(path: String, form: String) = client.send(
                    HttpRequest.newBuilder(URI.create(base + path))
                        .header("Content-Type", "application/x-www-form-urlencoded")
                        .POST(HttpRequest.BodyPublishers.ofString(form)).build(),
                    HttpResponse.BodyHandlers.ofString(),
                )
                var response = post("/games", "name=Test&selection=__RANDOM__")
                assertEquals(200, response.statusCode())
                val answerPath = Regex("/games/[^/\"]+/answer").find(response.body())!!.value
                for (number in 1..10) {
                    assertEquals(200, response.statusCode())
                    assertContains(response.body(), "Pregunta $number/10")
                    assertContains(response.body(), "Q$number")
                    if (replaced && number == 2) assertContains(response.body(), "Replacement answer")
                    response = post(answerPath, "option=0")
                }
                assertEquals(200, response.statusCode())
            }
            assertEquals(listOf(AiProfile.TERRA, AiProfile.TERRA), requests.map { it.profile })
            assertEquals(listOf("quiz10_coverage_route_from_plan", "quiz10_coverage_question_review"),
                requests.map { it.schemaName })
            if (replaced) {
                assertTrue(audits.any { it.reason == "Original answer incorrect" })
                assertTrue(audits.any { it.result == AiUsageAuditResult.ACCEPTED })
            }
        }
    }

    @Test
    fun unresolvedReplacementFailsWithoutAThirdCall() {
        var calls = 0
        val preparer = createQuizPreparer {
            calls++
            Outcome.Success(StructuredGeneration(if (calls == 1) coverage() else review(true, true), null))
        }
        assertIs<Outcome.Failure<*>>(preparer.prepare(StandardCoveragePlanner().random()))
        assertEquals(2, calls)
    }

    @Test
    fun realPreparationProducesTenPlayableQuestionsWithOnlyTwoTerraCalls() {
        assumeTrue(System.getenv("QUIZ10_REAL_PREPARATION") == "1")
        val config = assertIs<Outcome.Success<EnvironmentConfig>>(EnvironmentConfig.load()).value
        val client = OpenAiResponsesClient(config, UrlConnectionHttpTransport(5_000, 30_000))
        val requests = mutableListOf<StructuredGenerationRequest>()
        val preparer = createQuizPreparer { request ->
            requests += request
            client.generate(request)
        }
        val prepared = assertIs<Outcome.Success<PreparedQuiz>>(
            preparer.prepare(StandardCoveragePlanner().random())
        ).value
        assertEquals(10, prepared.questions!!.size)
        val flow = Quiz10Flow(prepared) { _, _ -> error("Unexpected additional AI call") }
        var state: Quiz10FlowState = assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start()).value
        for (number in 1..10) {
            assertEquals(number, assertIs<Quiz10FlowState.Question>(state).questionNumber)
            flow.answer(0)
            state = assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value
        }
        assertIs<Quiz10FlowState.Finished>(state)
        assertEquals(listOf(AiProfile.TERRA, AiProfile.TERRA), requests.map { it.profile })
        println("Real preparation: 10 questions, ${requests.size} TERRA calls, ${prepared.preparationMetrics}")
    }
}
