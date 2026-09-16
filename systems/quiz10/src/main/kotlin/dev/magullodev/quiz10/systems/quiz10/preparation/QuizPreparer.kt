package dev.magullodev.quiz10.systems.quiz10.preparation

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.question.QuizQuestion

class QuizPreparer(
    private val planTopic: (String) -> Outcome<QuizContentPlan, QuizContentPlanningError>,
) {
    fun prepare(topic: String): Outcome<PreparedQuiz, QuizPreparationError> {
        val plan = when (val result = planTopic(topic)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(QuizPreparationError.PlanningFailed(result.error))
        }
        val route = plan.toCoverageRoute()

        val questions = route.items.indices.map { index ->
            val planItem = plan.items[index]
            val correctOptionIndex = PreparedQuiz.correctOptionSequence[index]

            val options = planItem.distractors.map { it.text }.toMutableList()
            val feedback = planItem.distractors.map { it.explanation }.toMutableList()
            options.add(correctOptionIndex, planItem.answer)
            feedback.add(correctOptionIndex, planItem.correctExplanation)

            QuizQuestion(
                text = planItem.question,
                options = options,
                feedbackByOption = feedback,
                correctOptionIndex = correctOptionIndex,
            )
        }

        return Outcome.Success(PreparedQuiz(topic, route, questions))
    }
}

sealed interface QuizPreparationError {
    data class PlanningFailed(val cause: QuizContentPlanningError) : QuizPreparationError
}
