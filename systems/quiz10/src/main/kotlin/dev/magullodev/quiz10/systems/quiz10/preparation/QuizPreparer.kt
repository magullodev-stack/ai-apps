package dev.magullodev.quiz10.systems.quiz10.preparation

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRoute
import dev.magullodev.quiz10.systems.quiz10.coverage.terra.CoverageRouteGenerationError

class QuizPreparer(
    private val generateCoverageRoute: (String) -> Outcome<CoverageRoute, CoverageRouteGenerationError>,
) {
    fun prepare(topic: String): Outcome<PreparedQuiz, QuizPreparationError> {
        val route = when (val result = generateCoverageRoute(topic)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(QuizPreparationError.CoverageRouteGenerationFailed(result.error))
        }
        if (route.size != PreparedQuiz.correctOptionSequence.size) {
            return Outcome.Failure(QuizPreparationError.InvalidCoverageRouteSize(route.size))
        }

        return Outcome.Success(PreparedQuiz(topic, route))
    }
}

sealed interface QuizPreparationError {
    data class CoverageRouteGenerationFailed(val cause: CoverageRouteGenerationError) : QuizPreparationError
    data class InvalidCoverageRouteSize(val size: Int) : QuizPreparationError
}
