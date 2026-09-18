package dev.magullodev.quiz10.apps.quiz10.web

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.ai.StructuredGeneration
import dev.magullodev.aiapps.core.ai.StructuredGenerationRequest
import dev.magullodev.aiapps.core.contracts.Outcome
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull

class WebMainTest {
    private val legacyQuestionModelKey = "QUIZ10_" + "QUESTION_MODEL"

    @Test
    fun createQuizPreparerRequiresOnlyCoverageModel() {
        val preparer = createQuizPreparer(
            environment = { key ->
                when (key) {
                    "QUIZ10_COVERAGE_MODEL" -> "gpt-strong"
                    legacyQuestionModelKey -> error("Question model should not be requested")
                    else -> null
                }
            },
            generateStructured = ::unusedGeneration,
        )

        assertNotNull(preparer)
    }

    @Test
    fun createInteractionPresenterRequiresOnlyInteractionModel() {
        val presenter = createInteractionPresenter(
            environment = { key ->
                when (key) {
                    "QUIZ10_INTERACTION_MODEL" -> "gpt-luna"
                    legacyQuestionModelKey -> error("Question model should not be requested")
                    else -> null
                }
            },
            generateStructured = ::unusedGeneration,
        )

        assertNotNull(presenter)
    }

    @Test
    fun createQuizPreparerFailsWhenCoverageModelIsMissing() {
        val error = assertFailsWith<IllegalArgumentException> {
            createQuizPreparer(
                environment = { null },
                generateStructured = ::unusedGeneration,
            )
        }

        assertContains(error.message.orEmpty(), "QUIZ10_COVERAGE_MODEL")
    }

    @Test
    fun createInteractionPresenterFailsWhenInteractionModelIsMissing() {
        val error = assertFailsWith<IllegalArgumentException> {
            createInteractionPresenter(
                environment = { null },
                generateStructured = ::unusedGeneration,
            )
        }

        assertContains(error.message.orEmpty(), "QUIZ10_INTERACTION_MODEL")
    }

    private fun unusedGeneration(
        request: StructuredGenerationRequest,
    ): Outcome<StructuredGeneration, AiError> {
        error("Structured generation should not run while building the preparer: ${request.model}")
    }
}
