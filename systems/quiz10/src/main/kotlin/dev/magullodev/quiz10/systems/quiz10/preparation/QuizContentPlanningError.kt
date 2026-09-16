package dev.magullodev.quiz10.systems.quiz10.preparation

import dev.magullodev.aiapps.core.ai.AiError

sealed interface QuizContentPlanningError {
    data object BlankTopic : QuizContentPlanningError
    data class GenerationFailed(val cause: AiError) : QuizContentPlanningError
    data object InvalidGeneratedPlan : QuizContentPlanningError
}
