package dev.magullodev.quiz10.apps.quiz10

import dev.magullodev.aiapps.core.ai.OpenAiResponsesClient
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.UrlConnectionHttpTransport
import dev.magullodev.quiz10.systems.quiz10.coverage.CoveragePlanner
import kotlin.system.exitProcess

fun main(args: Array<String>) {
    val topic = args.joinToString(" ")
    val model = System.getenv("QUIZ10_COVERAGE_MODEL")
    if (model.isNullOrBlank()) {
        fail("CONFIGURATION_ERROR: QUIZ10_COVERAGE_MODEL debe contener un modelo no vacío")
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

    val output = System.out.bufferedWriter(Charsets.UTF_8)
    route.items.forEachIndexed { index, item ->
        output.appendLine("${index + 1}. Dificultad: ${item.difficulty}")
        output.appendLine("   Área: ${item.area}")
        output.appendLine("   Grupo: ${item.group}")
        output.appendLine("   Referente: ${item.referent}")
        output.appendLine("   Conocimiento: ${item.knowledge}")
        output.appendLine("   Respuesta: ${item.answer}")
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
