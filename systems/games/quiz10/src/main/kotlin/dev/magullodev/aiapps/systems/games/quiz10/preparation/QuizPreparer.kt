package dev.magullodev.aiapps.systems.games.quiz10.preparation

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.CoverageRouteGenerationError
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.CoverageRouteValidationError

class QuizPreparer(
    private val generateCoverageRoute: (String) -> Outcome<CoverageRoute, CoverageRouteGenerationError>,
    private val validateCoverageRoute: (String, CoverageRoute) -> Outcome<Unit, CoverageRouteValidationError>,
) {
    fun prepare(topic: String): Outcome<PreparedQuiz, QuizPreparationError> {
        val route = when (val result = generateCoverageRoute(topic)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(QuizPreparationError.CoverageRouteGenerationFailed(result.error))
        }
        if (route.size != PreparedQuiz.correctOptionSequence.size) {
            return Outcome.Failure(QuizPreparationError.InvalidCoverageRouteSize(route.size))
        }

        when (val result = validateCoverageRoute(topic, route)) {
            is Outcome.Success -> Unit
            is Outcome.Failure -> return Outcome.Failure(QuizPreparationError.CoverageRouteValidationFailed(result.error))
        }

        return Outcome.Success(PreparedQuiz(topic, route))
    }
}

sealed interface QuizPreparationError {
    data class CoverageRouteGenerationFailed(val cause: CoverageRouteGenerationError) : QuizPreparationError
    data class CoverageRouteValidationFailed(val cause: CoverageRouteValidationError) : QuizPreparationError
    data class InvalidCoverageRouteSize(val size: Int) : QuizPreparationError
}
