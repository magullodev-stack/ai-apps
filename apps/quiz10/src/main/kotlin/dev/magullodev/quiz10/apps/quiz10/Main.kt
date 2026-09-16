package dev.magullodev.quiz10.apps.quiz10

import dev.magullodev.aiapps.core.ai.OpenAiResponsesClient
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.UrlConnectionHttpTransport
import dev.magullodev.quiz10.systems.quiz10.coverage.CoveragePlanner
import dev.magullodev.quiz10.systems.quiz10.question.QuestionGenerator
import dev.magullodev.quiz10.systems.quiz10.session.QuizSession
import kotlin.system.exitProcess

fun main(args: Array<String>) {
    val output = System.out.bufferedWriter(Charsets.UTF_8)
    val input = System.`in`.bufferedReader(Charsets.UTF_8)
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
    val route = when (val result = planner.plan(topic)) {
        is Outcome.Success -> result.value
        is Outcome.Failure -> fail("PLANNING_ERROR: ${result.error}")
    }

    var session = QuizSession.start(route)
    val generator = QuestionGenerator(questionModel, client::generate)
    val correctIndexPattern = listOf(0, 1, 2, 3, 0, 1, 2, 3, 0, 1)

    while (!session.isFinished) {
        val currentItem = session.currentItem ?: break
        val currentQuestionNumber = session.currentQuestionNumber ?: break
        val correctOptionIndex = correctIndexPattern[currentQuestionNumber - 1]
        val question = when (val result = generator.generate(currentItem, correctOptionIndex)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> fail("QUESTION_GENERATION_ERROR: ${result.error}")
        }

        output.appendLine("Pregunta $currentQuestionNumber/10")
        output.appendLine("Área: ${currentItem.area}")
        output.appendLine()
        output.appendLine(question.text)
        output.appendLine()
        question.options.forEachIndexed { index, option ->
            output.appendLine("${'A' + index}) $option")
        }

        while (true) {
            output.append("Respuesta (A-D): ")
            output.flush()
            val answer = input.readLine() ?: fail("INPUT_EOF: no se ha recibido una respuesta")
            val option = answer.trim().singleOrNull()?.uppercaseChar()
            if (option == null || option !in 'A'..'D') {
                output.appendLine("Respuesta inválida. Usa A, B, C o D.")
                continue
            }

            val selectedIndex = option - 'A'
            val isCorrect = question.isCorrect(selectedIndex)
            val correction = if (isCorrect) "✅ CORRECTO" else "❌ INCORRECTO"
            output.appendLine("$correction — ${question.options[question.correctOptionIndex]}")
            session = session.recordAnswer(isCorrect)
            output.appendLine("Progreso: ${session.answeredQuestions}/10")
            output.appendLine("Aciertos: ${session.correctAnswers}")
            output.appendLine()
            break
        }
        output.flush()
    }

    output.appendLine("Partida terminada")
    output.appendLine("Puntuación final ${session.correctAnswers}/10")
    output.flush()
}

private fun fail(message: String): Nothing {
    System.err.bufferedWriter(Charsets.UTF_8).apply {
        appendLine(message)
        flush()
    }
    exitProcess(1)
}
