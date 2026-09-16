package dev.magullodev.quiz10.apps.quiz10

import dev.magullodev.aiapps.core.ai.OpenAiResponsesClient
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.UrlConnectionHttpTransport
import dev.magullodev.quiz10.systems.quiz10.coverage.CoveragePlanner
import dev.magullodev.quiz10.systems.quiz10.question.QuestionGenerator
import kotlin.system.exitProcess

fun main(args: Array<String>) {
    val topic = args.joinToString(" ")
    val model = System.getenv("QUIZ10_COVERAGE_MODEL")
    if (model.isNullOrBlank()) {
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
    val planner = CoveragePlanner(model, client::generate)
    val route = when (val result = planner.plan(topic)) {
        is Outcome.Success -> result.value
        is Outcome.Failure -> fail("PLANNING_ERROR: ${result.error}")
    }

    val item = route.items.first()
    val generator = QuestionGenerator(questionModel, client::generate)
    val question = when (val result = generator.generate(item, correctOptionIndex = 0)) {
        is Outcome.Success -> result.value
        is Outcome.Failure -> fail("QUESTION_GENERATION_ERROR: ${result.error}")
    }

    val output = System.out.bufferedWriter(Charsets.UTF_8)
    output.appendLine("Pregunta 1")
    output.appendLine("Área: ${item.area}")
    output.appendLine()
    output.appendLine(question.text)
    output.appendLine()
    question.options.forEachIndexed { index, option ->
        output.appendLine("${'A' + index}) $option")
    }
    output.flush()
}

private fun fail(message: String): Nothing {
    System.err.bufferedWriter(Charsets.UTF_8).apply {
        appendLine(message)
        flush()
    }
    exitProcess(1)
}
