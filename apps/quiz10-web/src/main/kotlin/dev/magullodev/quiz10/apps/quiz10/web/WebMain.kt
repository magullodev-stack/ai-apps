package dev.magullodev.quiz10.apps.quiz10.web

import dev.magullodev.aiapps.core.ai.OpenAiResponsesClient
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.UrlConnectionHttpTransport
import dev.magullodev.quiz10.systems.quiz10.coverage.CoveragePlanner
import dev.magullodev.quiz10.systems.quiz10.preparation.QuizPreparer
import dev.magullodev.quiz10.systems.quiz10.question.QuestionGenerator
import java.util.concurrent.CountDownLatch
import kotlin.system.exitProcess

fun main() {
    val coverageModel = System.getenv("QUIZ10_COVERAGE_MODEL")
    if (coverageModel.isNullOrBlank()) {
        fail("CONFIGURATION_ERROR: QUIZ10_COVERAGE_MODEL debe contener un modelo no vacío")
    }
    val questionModel = System.getenv("QUIZ10_QUESTION_MODEL")
    if (questionModel.isNullOrBlank()) {
        fail("CONFIGURATION_ERROR: QUIZ10_QUESTION_MODEL debe contener un modelo no vacío")
    }

    val config = when (val result = EnvironmentConfig.load()) {
        is Outcome.Success -> result.value
        is Outcome.Failure -> fail("CONFIGURATION_ERROR: ${result.error}")
    }

    val transport = UrlConnectionHttpTransport(5_000, 30_000)
    val client = OpenAiResponsesClient(config, transport)
    val planner = CoveragePlanner(coverageModel, client::generate)
    val generator = QuestionGenerator(questionModel, client::generate)
    val preparer = QuizPreparer(planner::plan, generator::generate)

    val server = Quiz10WebServer(preparer::prepare)
    val port = server.start()
    println("Quiz10 web running on http://0.0.0.0:$port")

    Runtime.getRuntime().addShutdownHook(Thread { server.close() })
    CountDownLatch(1).await()
}

private fun fail(message: String): Nothing {
    System.err.bufferedWriter(Charsets.UTF_8).use {
        it.appendLine(message)
    }
    exitProcess(1)
}
