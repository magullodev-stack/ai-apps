package dev.magullodev.quiz10.apps.quiz10

import dev.magullodev.aiapps.core.ai.OpenAiResponsesClient
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.UrlConnectionHttpTransport
import dev.magullodev.quiz10.systems.quiz10.coverage.CoveragePlanner
import dev.magullodev.quiz10.systems.quiz10.navigation.Quiz10NavigationMenu
import dev.magullodev.quiz10.systems.quiz10.preparation.QuizPreparer
import dev.magullodev.quiz10.systems.quiz10.preparation.QuizPreparationError
import dev.magullodev.quiz10.systems.quiz10.progress.PlayerProgress
import dev.magullodev.quiz10.systems.quiz10.question.QuestionGenerator
import dev.magullodev.quiz10.systems.quiz10.session.Quiz10Flow
import dev.magullodev.quiz10.systems.quiz10.session.Quiz10FlowState
import kotlin.system.exitProcess

fun main(args: Array<String>) {
    val output = System.out.bufferedWriter(Charsets.UTF_8)
    val input = System.`in`.bufferedReader(Charsets.UTF_8)
    output.append("Nombre: ")
    output.flush()
    val playerName = input.readLine() ?: fail("INPUT_EOF: no se ha recibido un nombre")
    val playerProgress = try {
        PlayerProgress.start(playerName)
    } catch (_: IllegalArgumentException) {
        fail("INPUT_ERROR: el nombre no puede estar vacío")
    }

    val topic = when {
        args.isNotEmpty() -> args.joinToString(" ")
        else -> {
            output.append("Tema: ")
            output.flush()
            input.readLine() ?: fail("INPUT_EOF: no se ha recibido un tema")
        }
    }.trim()
    if (topic.isBlank()) {
        fail("INPUT_ERROR: el tema no puede estar vacío")
    }

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
    val generator = QuestionGenerator(questionModel, client::generate)
    val preparer = QuizPreparer(planner::plan, generator::generate)

    val preparedQuiz = when (val result = preparer.prepare(topic)) {
        is Outcome.Success -> result.value
        is Outcome.Failure -> when (val error = result.error) {
            is QuizPreparationError.PlanningFailed -> fail("PLANNING_ERROR: ${error.cause}")
            is QuizPreparationError.GenerationFailed -> fail("QUESTION_GENERATION_ERROR: ${error.cause}")
        }
    }

    val flow = Quiz10Flow(preparedQuiz)
    var state: Quiz10FlowState = flow.start()
    renderState(state, output)
    var updatedProgress = playerProgress

    while (state !is Quiz10FlowState.Finished) {
        val questionState = state as? Quiz10FlowState.Question ?: break
        val selectedIndex = readValidAnswer(input, output)
        val answered = flow.answer(selectedIndex)
        val correction = if (answered.isCorrect) "✅ CORRECTO" else "❌ INCORRECTO"
        output.appendLine("$correction — ${questionState.question.options[questionState.question.correctOptionIndex]}")
        output.appendLine("Progreso: ${answered.answeredQuestions}/10")
        output.appendLine("Aciertos: ${answered.correctAnswers}")
        output.appendLine()

        val next = flow.advance()
        state = when (next) {
            is Outcome.Success -> next.value
            is Outcome.Failure -> error("Unexpected failure while advancing prepared quiz flow: ${next.error}")
        }
        renderState(state, output)
    }

    if (state is Quiz10FlowState.Finished) {
        updatedProgress = updatedProgress.recordQuiz(state.correctAnswers)
        renderPlayerProgress(updatedProgress, output)
        renderNavigationMenu(updatedProgress.playerName, topic, output)
    }

    output.flush()
}

private fun renderState(state: Quiz10FlowState, output: java.io.BufferedWriter) {
    when (state) {
        is Quiz10FlowState.Question -> {
            output.appendLine("Pregunta ${state.questionNumber}/10")
            output.appendLine("Área: ${state.area}")
            output.appendLine()
            output.appendLine(state.question.text)
            output.appendLine()
            state.question.options.forEachIndexed { index, option ->
                output.appendLine("${'A' + index}) $option")
            }
        }
        is Quiz10FlowState.Answered -> {
            output.appendLine("Respuesta registrada")
        }
        is Quiz10FlowState.Finished -> {
            output.appendLine("Partida terminada")
            output.appendLine("Puntuación final ${state.correctAnswers}/10")
        }
    }
}

private fun readValidAnswer(input: java.io.BufferedReader, output: java.io.BufferedWriter): Int {
    while (true) {
        output.append("Respuesta (A-D): ")
        output.flush()
        val answer = input.readLine() ?: fail("INPUT_EOF: no se ha recibido una respuesta")
        val option = answer.trim().singleOrNull()?.uppercaseChar()
        if (option == null || option !in 'A'..'D') {
            output.appendLine("Respuesta inválida. Usa A, B, C o D.")
            continue
        }
        return option - 'A'
    }
}

private fun renderPlayerProgress(progress: PlayerProgress, output: java.io.BufferedWriter) {
    output.appendLine("=== Progreso global ===")
    output.appendLine("Nombre: ${progress.playerName}")
    output.appendLine("Aciertos acumulados: ${progress.correctAnswers}")
    output.appendLine("Fallos acumulados: ${progress.incorrectAnswers}")
    output.appendLine("Porcentaje acumulado: ${progress.accuracyPercent}%")
    output.appendLine("Estrellas: ⭐ ${progress.stars}")
}

private fun renderNavigationMenu(playerName: String, topic: String, output: java.io.BufferedWriter) {
    val menu = Quiz10NavigationMenu.forTopic(topic)
    output.appendLine("=== Panel de navegación ===")
    menu.options.forEachIndexed { index, entry ->
        output.appendLine("${index + 1}. ${entry.label}")
    }
    output.appendLine("$playerName, escribe un número y seguimos.")
}

private fun fail(message: String): Nothing {
    System.err.bufferedWriter(Charsets.UTF_8).apply {
        appendLine(message)
        flush()
    }
    exitProcess(1)
}
