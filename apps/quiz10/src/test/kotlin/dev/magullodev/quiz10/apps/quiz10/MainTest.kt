package dev.magullodev.quiz10.apps.quiz10

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.config.AiModelsConfig
import dev.magullodev.aiapps.core.config.AppEnvironment
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import java.net.URI
import kotlin.test.Test
import kotlin.test.assertEquals

class MainTest {
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
}
