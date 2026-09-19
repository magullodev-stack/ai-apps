package dev.magullodev.aiapps.systems.games.quiz10.interaction

import dev.magullodev.aiapps.core.ai.AiError

sealed interface Quiz10InteractionError {
    data class GenerationFailed(val cause: AiError) : Quiz10InteractionError
    data object InvalidGeneratedMessage : Quiz10InteractionError
}