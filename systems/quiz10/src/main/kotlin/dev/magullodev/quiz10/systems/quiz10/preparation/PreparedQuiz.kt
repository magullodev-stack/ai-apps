package dev.magullodev.quiz10.systems.quiz10.preparation

import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRoute
import dev.magullodev.quiz10.systems.quiz10.question.QuizQuestion

class PreparedQuiz(
    val topic: String,
    val route: CoverageRoute,
    val questions: List<QuizQuestion>,
) {
    init {
        require(route.size == 10) { "Prepared quiz route must have exactly 10 positions" }
        require(questions.size == 10) { "Prepared quiz must contain exactly 10 questions" }
        require(questions.indices.all { index -> questions[index].correctOptionIndex == correctOptionSequence[index] }) {
            "Prepared quiz questions must preserve the deterministic correct option pattern"
        }
        require(route.items.indices.all { index -> route.items[index] == route.items[index] })
    }

    companion object {
        val correctOptionSequence = listOf(0, 1, 2, 3, 0, 1, 2, 3, 0, 1)
    }
}
