package dev.magullodev.aiapps.apps.quiz10.web

import dev.magullodev.aiapps.core.ai.OpenAiResponsesClient
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.UrlConnectionHttpTransport
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRouteItem
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.TerraCoverageQuestionReviewer
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.TerraCoverageRouteGenerator
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.TerraCoverageRouteValidator
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.TerraReplacementQuestionGenerator
import dev.magullodev.aiapps.systems.games.quiz10.interaction.Quiz10InteractionPresenter
import dev.magullodev.aiapps.systems.games.quiz10.preparation.CoverageQuestionCompleter
import dev.magullodev.aiapps.systems.games.quiz10.preparation.QuizPreparer
import dev.magullodev.aiapps.systems.games.quiz10.preparation.luna.LunaQuizTurnGenerator
import dev.magullodev.aiapps.systems.games.quiz10.preparation.luna.QuizTurnGenerationError
import dev.magullodev.aiapps.systems.games.quiz10.question.QuizQuestion
import java.util.concurrent.CountDownLatch
import kotlin.system.exitProcess

fun main() {
    val config = when (val result = EnvironmentConfig.load()) {
        is Outcome.Success -> result.value
        is Outcome.Failure -> fail("CONFIGURATION_ERROR: ${result.error}")
    }

    val transport = UrlConnectionHttpTransport(5_000, 30_000)
    val client = OpenAiResponsesClient(config, transport)
    val preparer = try {
        createQuizPreparer(client::generate)
    } catch (error: IllegalArgumentException) {
        fail(error.message ?: "CONFIGURATION_ERROR")
    }
    val turnGenerator = try {
        createTurnGenerator(client::generate)
    } catch (error: IllegalArgumentException) {
        fail(error.message ?: "CONFIGURATION_ERROR")
    }
    val interactionPresenter = try {
        createInteractionPresenter(client::generate)
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
        generateTurn = turnGenerator,
        presentInteraction = interactionPresenter::present,
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
    generateStructured: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
): QuizPreparer {
    val coverageGenerator = TerraCoverageRouteGenerator(generateStructured)
    val coverageValidator = TerraCoverageRouteValidator(generateStructured)
    val reviewer = TerraCoverageQuestionReviewer(generateStructured)
    val replacementGenerator = TerraReplacementQuestionGenerator(generateStructured)
    val completer = CoverageQuestionCompleter(replacementGenerator::generate)
    return QuizPreparer(
        generateCoverageRoute = coverageGenerator::generate,
        validateCoverageRoute = coverageValidator::validate,
        generateCoverageRouteFromPlan = coverageGenerator::generate,
        reviewCoverageQuestions = reviewer::review,
        completeCoverageQuestions = completer::complete,
    )
}

internal fun createTurnGenerator(
    generateStructured: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
): (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError> {
    val turnGenerator = LunaQuizTurnGenerator(generateStructured)
    return turnGenerator::generate
}

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
