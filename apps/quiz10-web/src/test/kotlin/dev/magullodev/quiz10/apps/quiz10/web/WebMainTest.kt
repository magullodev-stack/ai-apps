package dev.magullodev.quiz10.apps.quiz10.web

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.config.AiModelsConfig
import dev.magullodev.aiapps.core.config.AppEnvironment
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.interaction.Quiz10InteractionContext
import dev.magullodev.quiz10.systems.quiz10.interaction.Quiz10InteractionEvent
import java.net.URI
import kotlin.test.Test
import kotlin.test.assertEquals

class WebMainTest {
    private val config = EnvironmentConfig(
        AppEnvironment.TEST,
        URI("https://example.com"),
        "example-test-key",
        AiModelsConfig("configured-luna", "configured-mini", "configured-terra"),
    )

    @Test
    fun createQuizPreparerUsesGlobalTerraModel() {
        val requestedModels = mutableListOf<String>()
        val preparer = createQuizPreparer(config) { request ->
            requestedModels += request.model
            Outcome.Failure(AiError.TransportFailure)
        }

        preparer.prepare("Historia")

        assertEquals(listOf(config.aiModels.terra), requestedModels)
    }

    @Test
    fun createInteractionPresenterUsesGlobalLunaModel() {
        val requestedModels = mutableListOf<String>()
        val presenter = createInteractionPresenter(config) { request ->
            requestedModels += request.model
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

        assertEquals(listOf(config.aiModels.luna), requestedModels)
    }
}
