package dev.magullodev.aiapps.systems.games.quiz10.random.test.preguntas

import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageRouteItem

class QuizSession private constructor(
    private val route: CoverageRoute,
    val answeredQuestions: Int,
    val correctAnswers: Int,
) {
    val totalQuestions: Int = route.size

    val currentQuestionNumber: Int?
        get() = if (isFinished) null else answeredQuestions + 1

    val currentItem: CoverageRouteItem?
        get() = if (isFinished) null else route.items.getOrNull(answeredQuestions)

    val isFinished: Boolean
        get() = answeredQuestions >= totalQuestions

    companion object {
        fun start(route: CoverageRoute): QuizSession {
            require(route.size == 10) { "Quiz10 session requires exactly 10 coverage positions" }
            return QuizSession(route = route, answeredQuestions = 0, correctAnswers = 0)
        }
    }

    fun recordAnswer(isCorrect: Boolean): QuizSession {
        check(!isFinished) { "Quiz session is already finished" }

        val nextAnswered = answeredQuestions + 1
        val nextCorrect = correctAnswers + if (isCorrect) 1 else 0
        return QuizSession(route = route, answeredQuestions = nextAnswered, correctAnswers = nextCorrect)
    }
}
