package dev.magullodev.quiz10.systems.quiz10.preparation

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRoute
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRouteItem
import dev.magullodev.quiz10.systems.quiz10.coverage.terra.CoverageRouteGenerationError
import dev.magullodev.quiz10.systems.quiz10.preparation.luna.QuizTurnGenerationError
import dev.magullodev.quiz10.systems.quiz10.question.QuizQuestion

class QuizPreparer(
    private val generateCoverageRoute: (String) -> Outcome<CoverageRoute, CoverageRouteGenerationError>,
    private val generateTurn: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError>,
) {
    fun prepare(topic: String): Outcome<PreparedQuiz, QuizPreparationError> {
        val route = when (val result = generateCoverageRoute(topic)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(QuizPreparationError.CoverageRouteGenerationFailed(result.error))
        }
        if (route.size != PreparedQuiz.correctOptionSequence.size) {
            return Outcome.Failure(QuizPreparationError.InvalidCoverageRouteSize(route.size))
        }

        val questions = mutableListOf<QuizQuestion>()
        route.items.forEachIndexed { index, item ->
            val correctOptionIndex = PreparedQuiz.correctOptionSequence[index]
            when (val turn = generateTurn(item, correctOptionIndex)) {
                is Outcome.Success -> questions.add(turn.value)
                is Outcome.Failure -> {
                    return Outcome.Failure(
                        QuizPreparationError.TurnGenerationFailed(
                            questionNumber = index + 1,
                            cause = turn.error,
                        ),
                    )
                }
            }
        }

        return Outcome.Success(PreparedQuiz(topic, route, questions))
    }
}

sealed interface QuizPreparationError {
    data class CoverageRouteGenerationFailed(val cause: CoverageRouteGenerationError) : QuizPreparationError
    data class InvalidCoverageRouteSize(val size: Int) : QuizPreparationError
    data class TurnGenerationFailed(
        val questionNumber: Int,
        val cause: QuizTurnGenerationError,
    ) : QuizPreparationError
}
