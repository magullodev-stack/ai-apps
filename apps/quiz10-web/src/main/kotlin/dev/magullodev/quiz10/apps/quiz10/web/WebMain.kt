package dev.magullodev.quiz10.apps.quiz10.web

import dev.magullodev.aiapps.core.ai.OpenAiResponsesClient
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.UrlConnectionHttpTransport
import dev.magullodev.quiz10.systems.quiz10.interaction.Quiz10InteractionPresenter
import dev.magullodev.quiz10.systems.quiz10.preparation.QuizContentPlanner
import dev.magullodev.quiz10.systems.quiz10.preparation.QuizPreparer
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
        createQuizPreparer(System::getenv, client::generate)
    } catch (error: IllegalArgumentException) {
        fail(error.message ?: "CONFIGURATION_ERROR")
    }
    val interactionPresenter = try {
        createInteractionPresenter(System::getenv, client::generate)
    } catch (error: IllegalArgumentException) {
        fail(error.message ?: "CONFIGURATION_ERROR")
    }

    val server = Quiz10WebServer(preparer::prepare, interactionPresenter::present)
    val port = server.start()
    println("Quiz10 web running on http://0.0.0.0:$port")

    Runtime.getRuntime().addShutdownHook(Thread { server.close() })
    CountDownLatch(1).await()
}

internal fun createQuizPreparer(
    environment: (String) -> String?,
    generateStructured: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
): QuizPreparer {
    val coverageModel = environment("QUIZ10_COVERAGE_MODEL")
    require(!coverageModel.isNullOrBlank()) {
        "CONFIGURATION_ERROR: QUIZ10_COVERAGE_MODEL debe contener un modelo no vacío"
    }
    val planner = QuizContentPlanner(coverageModel, generateStructured)
    return QuizPreparer(planner::plan)
}

internal fun createInteractionPresenter(
    environment: (String) -> String?,
    generateStructured: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
): Quiz10InteractionPresenter {
    val interactionModel = environment("QUIZ10_INTERACTION_MODEL")
    require(!interactionModel.isNullOrBlank()) {
        "CONFIGURATION_ERROR: QUIZ10_INTERACTION_MODEL debe contener un modelo no vacío"
    }
    return Quiz10InteractionPresenter(interactionModel, generateStructured)
}

private fun fail(message: String): Nothing {
    System.err.bufferedWriter(Charsets.UTF_8).use {
        it.appendLine(message)
    }
    exitProcess(1)
}
