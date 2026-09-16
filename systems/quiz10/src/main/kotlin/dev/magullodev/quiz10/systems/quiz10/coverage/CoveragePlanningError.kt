package dev.magullodev.quiz10.systems.quiz10.coverage

import dev.magullodev.aiapps.core.ai.AiError

sealed interface CoveragePlanningError {
    data object BlankTopic : CoveragePlanningError
    data class GenerationFailed(val cause: AiError) : CoveragePlanningError
    data object InvalidGeneratedRoute : CoveragePlanningError
}
