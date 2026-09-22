package dev.magullodev.aiapps.apps.quiz10.web

import dev.magullodev.aiapps.core.ai.OpenAiResponsesClient
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.AiUsageAuditEvent
import dev.magullodev.aiapps.core.ai.AiUsageAuditResult
import dev.magullodev.aiapps.core.ai.AiUsageContextHolder
import dev.magullodev.aiapps.core.ai.AiUsageMonitor
import dev.magullodev.aiapps.core.ai.FileAiUsageMonitor
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.ai.loadModelRates
import dev.magullodev.aiapps.core.ai.resolveUsageFile
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.UrlConnectionHttpTransport
import dev.magullodev.aiapps.systems.games.quiz10.random.test.procesamiento.CoverageQuestionReviewPosition
import dev.magullodev.aiapps.systems.games.quiz10.random.test.procesamiento.CoverageRouteValidationError
import dev.magullodev.aiapps.systems.games.quiz10.random.test.procesamiento.TerraCoverageQuestionReviewer
import dev.magullodev.aiapps.systems.games.quiz10.random.test.procesamiento.TerraCoverageRouteGenerator
import dev.magullodev.aiapps.systems.games.quiz10.random.test.procesamiento.TerraCoverageRouteValidator
import dev.magullodev.aiapps.systems.games.quiz10.interaction.Quiz10InteractionPresenter
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageQuestionAuditListener
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageQuestionCompleter
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.QuizPreparer
import java.util.concurrent.CountDownLatch
import kotlin.system.exitProcess

fun main(args: Array<String>) {
    val config = when (val result = EnvironmentConfig.load()) {
        is Outcome.Success -> result.value
        is Outcome.Failure -> fail("CONFIGURATION_ERROR: ${result.error}")
    }

    val transport = UrlConnectionHttpTransport(5_000, 30_000)
    val usageMonitor: AiUsageMonitor = FileAiUsageMonitor(resolveUsageFile(), loadModelRates())
    val client = OpenAiResponsesClient(config, transport, usageMonitor)
    val preparer = try {
        createQuizPreparer(usageMonitor = usageMonitor, generateStructured = client::generate)
    } catch (error: IllegalArgumentException) {
        fail(error.message ?: "CONFIGURATION_ERROR")
    }
    val port = try {
        resolveWebPort()
    } catch (error: IllegalArgumentException) {
        fail(error.message ?: "CONFIGURATION_ERROR")
    }

    val server = Quiz10WebServer(
        prepareQuiz = preparer::prepare,
        usageMonitor = usageMonitor,
        port = port,
    )
    val boundPort = server.start()
    println("Quiz10 web running on http://0.0.0.0:$boundPort")

    Runtime.getRuntime().addShutdownHook(Thread { server.close() })
    CountDownLatch(1).await()
}

internal fun resolveWebPort(env: Map<String, String> = System.getenv()): Int {
    val raw = env["QUIZ10_WEB_PORT"]?.trim().orEmpty()
    if (raw.isEmpty()) return 8080

    val value = raw.toIntOrNull()
        ?: throw IllegalArgumentException("CONFIGURATION_ERROR: QUIZ10_WEB_PORT must be an integer between 1 and 65535")
    if (value !in 1..65535) {
        throw IllegalArgumentException("CONFIGURATION_ERROR: QUIZ10_WEB_PORT must be an integer between 1 and 65535")
    }
    return value
}

internal fun createQuizPreparer(
    usageMonitor: AiUsageMonitor = AiUsageMonitor.NOOP,
    generateStructured: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
): QuizPreparer {
    val coverageGenerator = TerraCoverageRouteGenerator(generateStructured)
    val coverageValidator = TerraCoverageRouteValidator(generateStructured)
    val reviewer = TerraCoverageQuestionReviewer(generateStructured)

    val validateWithAudit: (String, dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageRoute) -> Outcome<Unit, CoverageRouteValidationError> = { topic, route ->
        val result = coverageValidator.validate(topic, route)
        val error = (result as? Outcome.Failure)?.error
        if (error is CoverageRouteValidationError.RouteRejected) {
            error.issues.forEach { issue ->
                usageMonitor.recordAudit(
                    AiUsageAuditEvent(
                        application = currentUsageApplication(),
                        workUnitId = currentWorkUnitId(),
                        audit = "quiz10_route_validation",
                        phase = "route_validation",
                        position = null,
                        attempt = null,
                        result = AiUsageAuditResult.REJECTED,
                        reason = issue,
                    ),
                )
            }
        }
        result
    }

    val reviewWithAudit: (dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageRoute) -> Outcome<dev.magullodev.aiapps.systems.games.quiz10.random.test.procesamiento.CoverageQuestionReview, dev.magullodev.aiapps.systems.games.quiz10.random.test.procesamiento.CoverageQuestionReviewError> = { route ->
        val result = reviewer.review(route)
        if (result is Outcome.Success) {
            result.value.positions.forEachIndexed { index, reviewed ->
                val issue = when (reviewed) {
                    is CoverageQuestionReviewPosition.Invalid -> reviewed.issue
                    is CoverageQuestionReviewPosition.Replaced -> reviewed.issue
                    is CoverageQuestionReviewPosition.Valid -> null
                }
                if (issue != null) {
                    usageMonitor.recordAudit(
                        AiUsageAuditEvent(
                            application = currentUsageApplication(),
                            workUnitId = currentWorkUnitId(),
                            audit = "quiz10_question_review",
                            phase = "initial_review",
                            position = index + 1,
                            attempt = null,
                            result = AiUsageAuditResult.REJECTED,
                            reason = issue,
                        ),
                    )
                }
            }
        }
        result
    }

    val completer = CoverageQuestionCompleter(
        auditListener = object : CoverageQuestionAuditListener {
            override fun onInitialReviewRejected(position: Int, issue: String) {
                // Initial review rejections are recorded in reviewWithAudit to preserve original issues.
            }

            override fun onReplacementOutcome(position: Int, attempt: Int, accepted: Boolean, issue: String?) {
                usageMonitor.recordAudit(
                    AiUsageAuditEvent(
                        application = currentUsageApplication(),
                        workUnitId = currentWorkUnitId(),
                        audit = "quiz10_question_replacement",
                        phase = "replacement",
                        position = position,
                        attempt = attempt,
                        result = if (accepted) AiUsageAuditResult.ACCEPTED else AiUsageAuditResult.REJECTED,
                        reason = issue,
                    ),
                )
            }
        },
    )

    return QuizPreparer(
        generateCoverageRoute = coverageGenerator::generate,
        validateCoverageRoute = validateWithAudit,
        generateCoverageRouteFromPlan = coverageGenerator::generate,
        reviewCoverageQuestions = reviewWithAudit,
        completeCoverageQuestions = completer::complete,
    )
}

private fun currentUsageApplication(): String = AiUsageContextHolder.current()?.application ?: QUIZ10_APPLICATION

private fun currentWorkUnitId(): String? = AiUsageContextHolder.current()?.workUnitId

internal fun createInteractionPresenter(
    generateStructured: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
): Quiz10InteractionPresenter {
    return Quiz10InteractionPresenter(generateStructured)
}

private fun fail(message: String): Nothing {
    System.err.bufferedWriter(Charsets.UTF_8).use {
        it.appendLine(message)
    }
    exitProcess(1)
}

private const val QUIZ10_APPLICATION = "quiz10-web"
