package dev.magullodev.quiz10.apps.quiz10.web

import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.interaction.Quiz10InteractionContext
import dev.magullodev.quiz10.systems.quiz10.interaction.Quiz10InteractionEvent
import kotlin.test.Test
import kotlin.test.assertEquals

class WebMainTest {
    @Test
    fun createQuizPreparerUsesGlobalTerraProfile() {
        val requestedProfiles = mutableListOf<AiProfile>()
        val preparer = createQuizPreparer { request ->
            requestedProfiles += request.profile
            Outcome.Failure(AiError.TransportFailure)
        }

        preparer.prepare("Historia")

        assertEquals(listOf(AiProfile.TERRA), requestedProfiles)
    }

    @Test
    fun createInteractionPresenterUsesGlobalLunaProfile() {
        val requestedProfiles = mutableListOf<AiProfile>()
        val presenter = createInteractionPresenter { request ->
            requestedProfiles += request.profile
            Outcome.Failure(AiError.TransportFailure)
        }

        presenter.present(
            Quiz10InteractionContext(
                event = Quiz10InteractionEvent.WELCOME,
                playerName = "Ana",
                topic = "Historia",
                answeredQuestions = 0,
                correctAnswers = 0,
                totalQuestions = 10,
                stars = 0,
                lastAnswerCorrect = null,
                starEarned = false,
            ),
        )

        assertEquals(listOf(AiProfile.LUNA), requestedProfiles)
    }
}
