package dev.magullodev.quiz10.apps.quiz10

import dev.magullodev.aiapps.core.ai.AiProfile
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.contracts.Outcome
import kotlin.test.Test
import kotlin.test.assertEquals

class MainTest {
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
}
