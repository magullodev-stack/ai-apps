package dev.magullodev.quiz10.apps.quiz10

import dev.magullodev.aiapps.core.ai.OpenAiResponsesClient
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.UrlConnectionHttpTransport
import dev.magullodev.quiz10.systems.quiz10.navigation.Quiz10NavigationOption
import dev.magullodev.quiz10.systems.quiz10.navigation.Quiz10NavigationMenu
import dev.magullodev.quiz10.systems.quiz10.preparation.QuizContentPlanner
import dev.magullodev.quiz10.systems.quiz10.preparation.QuizPreparer
import dev.magullodev.quiz10.systems.quiz10.preparation.QuizPreparationError
import dev.magullodev.quiz10.systems.quiz10.progress.PlayerProgress
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

    var currentTopic = if (args.isNotEmpty()) {
        args.joinToString(" ").trim().also {
            if (it.isBlank()) fail("INPUT_ERROR: el tema no puede estar vacío")
        }
    } else {
        readTopic(input, output)
    }

    val config = when (val result = EnvironmentConfig.load()) {
        is Outcome.Success -> result.value
        is Outcome.Failure -> fail("CONFIGURATION_ERROR: ${result.error}")
    }
    val transport = UrlConnectionHttpTransport(5_000, 30_000)
    val client = OpenAiResponsesClient(config, transport)
    val preparer = try {
        createQuizPreparer(config, client::generate)
    } catch (error: IllegalArgumentException) {
        fail(error.message ?: "CONFIGURATION_ERROR")
    }
    var updatedProgress = playerProgress
    var latestFinished: Quiz10FlowState.Finished? = null

    while (true) {
        val finishedState = playQuiz(currentTopic, preparer, input, output)
        latestFinished = finishedState
        updatedProgress = updatedProgress.recordQuiz(finishedState.correctAnswers)

        while (true) {
            renderPlayerProgress(updatedProgress, output)
            val menu = renderNavigationMenu(updatedProgress.playerName, currentTopic, output)
            val selectedOption = readNavigationSelection(menu, input, output)

            when (selectedOption) {
                Quiz10NavigationOption.ANOTHER_QUIZ_SAME_TOPIC -> break
                Quiz10NavigationOption.CHOOSE_ANOTHER_TOPIC -> {
                    currentTopic = readTopic(input, output)
                    break
                }
                Quiz10NavigationOption.REVIEW_WRONG_ANSWERS -> {
                    renderFailedAnswers(latestFinished, output)
                    continue
                }
                Quiz10NavigationOption.RANDOM_QUIZ,
                Quiz10NavigationOption.VIEW_SOURCES,
                Quiz10NavigationOption.CREATE_IMAGE_QUIZ -> {
                    output.appendLine("Opción todavía no disponible.")
                    output.flush()
                    return
                }
            }
        }
    }

    output.flush()
}

internal fun createQuizPreparer(
    config: EnvironmentConfig,
    generateStructured: (StructuredGenerationRequest) -> Outcome<StructuredGeneration, AiError>,
): QuizPreparer {
    val planner = QuizContentPlanner(config.aiModels.terra, generateStructured)
    return QuizPreparer(planner::plan)
}

private fun playQuiz(
    topic: String,
    preparer: QuizPreparer,
    input: java.io.BufferedReader,
    output: java.io.BufferedWriter,
): Quiz10FlowState.Finished {
    val preparedQuiz = when (val result = preparer.prepare(topic)) {
        is Outcome.Success -> result.value
        is Outcome.Failure -> when (val error = result.error) {
            is QuizPreparationError.PlanningFailed -> fail("PLANNING_ERROR: ${error.cause}")
        }
    }

    val flow = Quiz10Flow(preparedQuiz)
    var state: Quiz10FlowState = flow.start()
    renderState(state, output)

    while (state !is Quiz10FlowState.Finished) {
        val questionState = state as? Quiz10FlowState.Question ?: break
        val selectedIndex = readValidAnswer(input, output)
        val answered = flow.answer(selectedIndex)
        val correction = if (answered.isCorrect) "✅ CORRECTO" else "❌ INCORRECTO"
        output.appendLine("$correction — ${questionState.question.options[questionState.question.correctOptionIndex]}")
        output.appendLine(questionState.question.feedbackFor(selectedIndex))
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

    return state as? Quiz10FlowState.Finished
        ?: error("Quiz flow did not finish as expected")
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

private fun renderNavigationMenu(playerName: String, topic: String, output: java.io.BufferedWriter): Quiz10NavigationMenu {
    val menu = Quiz10NavigationMenu.forTopic(topic)
    output.appendLine("=== Panel de navegación ===")
    menu.options.forEachIndexed { index, entry ->
        output.appendLine("${index + 1}. ${entry.label}")
    }
    output.appendLine("$playerName, escribe un número y seguimos.")
    return menu
}

private fun renderFailedAnswers(finishedState: Quiz10FlowState.Finished?, output: java.io.BufferedWriter) {
    val state = finishedState ?: return
    if (state.failedAnswers.isEmpty()) {
        output.appendLine("No tienes respuestas fallidas en este Quiz10.")
        return
    }

    state.failedAnswers.forEach { answer ->
        output.appendLine("Pregunta ${answer.questionNumber}: ${answer.question.text}")
        output.appendLine("Tu respuesta: ${answer.selectedAnswer}")
        output.appendLine("Respuesta correcta: ${answer.correctAnswer}")
        output.appendLine()
    }
}

private fun readNavigationSelection(
    menu: Quiz10NavigationMenu,
    input: java.io.BufferedReader,
    output: java.io.BufferedWriter,
): Quiz10NavigationOption {
    while (true) {
        output.append("Selección (1-6): ")
        output.flush()
        val line = input.readLine() ?: fail("INPUT_EOF: no se ha recibido una selección")
        val value = line.trim().toIntOrNull()
        if (value == null) {
            output.appendLine("Entrada inválida. Escribe un número entre 1 y 6.")
            continue
        }

        try {
            return menu.select(value)
        } catch (_: IllegalArgumentException) {
            output.appendLine("Entrada inválida. Escribe un número entre 1 y 6.")
        }
    }
}

private fun readTopic(input: java.io.BufferedReader, output: java.io.BufferedWriter): String {
    output.append("Tema: ")
    output.flush()
    val topic = input.readLine() ?: fail("INPUT_EOF: no se ha recibido un tema")
    return topic.trim().also {
        if (it.isBlank()) fail("INPUT_ERROR: el tema no puede estar vacío")
    }
}

private fun fail(message: String): Nothing {
    System.err.bufferedWriter(Charsets.UTF_8).apply {
        appendLine(message)
        flush()
    }
    exitProcess(1)
}
