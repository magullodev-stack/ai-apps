package dev.magullodev.quiz10.systems.quiz10.question

import dev.magullodev.aiapps.core.ai.AiError

sealed interface QuestionGenerationError {
    data class GenerationFailed(val cause: AiError) : QuestionGenerationError
    data object InvalidGeneratedQuestion : QuestionGenerationError
}
