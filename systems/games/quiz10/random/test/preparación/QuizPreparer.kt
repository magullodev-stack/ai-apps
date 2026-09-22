package dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.StandardCoveragePlan
import dev.magullodev.aiapps.systems.games.quiz10.random.test.procesamiento.CoverageQuestionReview
import dev.magullodev.aiapps.systems.games.quiz10.random.test.procesamiento.CoverageQuestionReviewError
import dev.magullodev.aiapps.systems.games.quiz10.random.test.procesamiento.CoverageRouteGenerationError
import dev.magullodev.aiapps.systems.games.quiz10.random.test.procesamiento.CoverageRouteValidationError

class QuizPreparer(
    private val generateCoverageRoute: (String) -> Outcome<CoverageRoute, CoverageRouteGenerationError>,
    private val validateCoverageRoute: (String, CoverageRoute) -> Outcome<Unit, CoverageRouteValidationError>,
    private val generateCoverageRouteFromPlan: ((StandardCoveragePlan) -> Outcome<CoverageRoute, CoverageRouteGenerationError>)? = null,
    private val reviewCoverageQuestions: ((CoverageRoute) -> Outcome<CoverageQuestionReview, CoverageQuestionReviewError>)? = null,
    private val completeCoverageQuestions: ((StandardCoveragePlan, CoverageRoute, CoverageQuestionReview) -> Outcome<CompletedCoverageQuestions, CoverageQuestionCompletionError>)? = null,
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

    fun prepare(plan: StandardCoveragePlan): Outcome<PreparedQuiz, QuizPreparationError> {
        val startedNanos = System.nanoTime()
        val routeGenerator = generateCoverageRouteFromPlan
            ?: return Outcome.Failure(QuizPreparationError.StandardPreparationNotConfigured)
        val reviewer = reviewCoverageQuestions
            ?: return Outcome.Failure(QuizPreparationError.StandardPreparationNotConfigured)
        val completer = completeCoverageQuestions
            ?: return Outcome.Failure(QuizPreparationError.StandardPreparationNotConfigured)

        val route = when (val result = routeGenerator(plan)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> {
                return Outcome.Failure(QuizPreparationError.StandardCoverageRouteGenerationFailed(result.error))
            }
        }

        val review = when (val result = reviewer(route)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> {
                return Outcome.Failure(QuizPreparationError.CoverageQuestionReviewFailed(result.error))
            }
        }

        val completed = when (val result = completer(plan, route, review)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> {
                return Outcome.Failure(QuizPreparationError.CoverageQuestionCompletionFailed(result.error))
            }
        }

        val topic = derivedTopicFromPlan(plan)
        val questions = completed.positions.map {
            PreparedQuizQuestion(
                question = it.question,
                answer = it.answer,
                distractors = it.distractors,
            )
        }
        val preparationDurationMillis = (System.nanoTime() - startedNanos).coerceAtLeast(0) / 1_000_000
        val metrics = PreparedQuizPreparationMetrics(
            preparationDurationMillis = preparationDurationMillis,
            invalidatedPositions = completed.invalidatedPositions,
            replacedQuestions = completed.replacedQuestions,
            replacementAttempts = completed.replacementAttempts,
        )
        return Outcome.Success(PreparedQuiz(topic = topic, route = route, questions = questions, preparationMetrics = metrics))
    }

    private fun derivedTopicFromPlan(plan: StandardCoveragePlan): String {
        val labels = plan.positions.map { it.area.label }.distinct()
        return if (labels.size == 1) labels.single() else "Aleatorio"
    }
}

sealed interface QuizPreparationError {
    data class CoverageRouteGenerationFailed(val cause: CoverageRouteGenerationError) : QuizPreparationError
    data class CoverageRouteValidationFailed(val cause: CoverageRouteValidationError) : QuizPreparationError
    data class StandardCoverageRouteGenerationFailed(val cause: CoverageRouteGenerationError) : QuizPreparationError
    data class CoverageQuestionReviewFailed(val cause: CoverageQuestionReviewError) : QuizPreparationError
    data class CoverageQuestionCompletionFailed(val cause: CoverageQuestionCompletionError) : QuizPreparationError
    data object StandardPreparationNotConfigured : QuizPreparationError
    data class InvalidCoverageRouteSize(val size: Int) : QuizPreparationError
}
