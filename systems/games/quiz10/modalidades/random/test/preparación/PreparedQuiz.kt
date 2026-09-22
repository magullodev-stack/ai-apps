package dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación

import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageRoute
import java.util.Collections

class PreparedQuiz(
    val topic: String,
    val route: CoverageRoute,
    questions: List<PreparedQuizQuestion>? = null,
    val preparationMetrics: PreparedQuizPreparationMetrics? = null,
) {
    val questions: List<PreparedQuizQuestion>? = questions?.let { Collections.unmodifiableList(it.toList()) }

    init {
        require(route.size == 10) { "Prepared quiz route must have exactly 10 positions" }
        if (this.questions != null) {
            require(this.questions.size == route.size) { "Prepared quiz questions must match route size" }
        }
    }

    companion object {
        val correctOptionSequence = listOf(0, 1, 2, 3, 0, 1, 2, 3, 0, 1)
    }
}

data class PreparedQuizPreparationMetrics(
    val preparationDurationMillis: Long,
    val invalidatedPositions: Int,
    val replacedQuestions: Int,
    val replacementAttempts: Int,
) {
    init {
        require(preparationDurationMillis >= 0) { "Preparation duration must be >= 0" }
        require(invalidatedPositions >= 0) { "Invalidated positions must be >= 0" }
        require(replacedQuestions >= 0) { "Replaced questions must be >= 0" }
        require(replacementAttempts >= 0) { "Replacement attempts must be >= 0" }
    }
}

data class PreparedQuizQuestion(
    val question: String,
    val answer: String,
    val distractors: List<String>,
) {
    init {
        require(question.isNotBlank()) { "Prepared question text must not be blank" }
        require(answer.isNotBlank()) { "Prepared question answer must not be blank" }
        require(distractors.size == 3) { "Prepared question must contain exactly three distractors" }
        require(distractors.all { it.isNotBlank() }) { "Prepared question distractors must not be blank" }
    }
}
