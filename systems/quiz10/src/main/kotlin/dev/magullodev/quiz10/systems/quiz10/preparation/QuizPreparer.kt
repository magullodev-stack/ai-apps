package dev.magullodev.quiz10.systems.quiz10.preparation

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoveragePlanningError
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRoute
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRouteItem
import dev.magullodev.quiz10.systems.quiz10.question.QuestionGenerationError
import dev.magullodev.quiz10.systems.quiz10.question.QuizQuestion

class QuizPreparer(
    private val planTopic: (String) -> Outcome<CoverageRoute, CoveragePlanningError>,
    private val generateQuestion: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuestionGenerationError>,
) {
    fun prepare(topic: String): Outcome<PreparedQuiz, QuizPreparationError> {
        val route = when (val result = planTopic(topic)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(QuizPreparationError.PlanningFailed(result.error))
        }

        require(route.size == 10) { "Prepared quiz route must have exactly 10 positions" }

        val questions = mutableListOf<QuizQuestion>()
        for (index in route.items.indices) {
            val correctOptionIndex = PreparedQuiz.correctOptionSequence[index]
            val questionOutcome = generateQuestion(route.items[index], correctOptionIndex)
            when (questionOutcome) {
                is Outcome.Success -> questions += questionOutcome.value
                is Outcome.Failure -> return Outcome.Failure(
                    QuizPreparationError.GenerationFailed(
                        questionNumber = index + 1,
                        cause = questionOutcome.error,
                    ),
                )
            }
        }

        return Outcome.Success(PreparedQuiz(topic, route, questions))
    }
}

sealed interface QuizPreparationError {
    data class PlanningFailed(val cause: CoveragePlanningError) : QuizPreparationError
    data class GenerationFailed(
        val questionNumber: Int,
        val cause: QuestionGenerationError,
    ) : QuizPreparationError
}
