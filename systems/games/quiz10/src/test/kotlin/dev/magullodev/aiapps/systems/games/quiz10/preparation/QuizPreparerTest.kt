package dev.magullodev.aiapps.systems.games.quiz10.preparation

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRouteItem
import dev.magullodev.aiapps.systems.games.quiz10.random.test.processing.CoverageRouteGenerationError
import dev.magullodev.aiapps.systems.games.quiz10.random.test.processing.CoverageRouteValidationError
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class QuizPreparerTest {
    private fun route() = CoverageRoute.of(List(10) { index ->
        CoverageRouteItem(
            difficulty = when (index) {
                in 0..3 -> CoverageDifficulty.EASY
                in 4..6 -> CoverageDifficulty.MODERATE
                in 7..8 -> CoverageDifficulty.HARD
                else -> CoverageDifficulty.VERY_HARD
            },
            area = if (index % 2 == 0) "History" else "Culture",
            group = if (index % 3 == 0) "Ancient Rome" else "Republic",
            referent = "Referent $index",
            knowledge = "Knowledge $index",
            answer = "Answer $index",
        )
    })

    @Test
    fun prepareBuildsPreparedQuizFromSingleCoverageGenerationOnly() {
        var coverageCalls = 0
        var validationCalls = 0
        val prepared = assertIs<Outcome.Success<PreparedQuiz>>(
            QuizPreparer(
                generateCoverageRoute = {
                    coverageCalls += 1
                    Outcome.Success(route())
                },
                validateCoverageRoute = { _, _ ->
                    validationCalls += 1
                    Outcome.Success(Unit)
                },
            ).prepare("IA"),
        ).value

        assertEquals(1, coverageCalls)
        assertEquals(1, validationCalls)
        assertEquals(10, prepared.route.size)
        assertEquals(route().items, prepared.route.items)
    }

    @Test
    fun preparedQuizKeepsDeterministicPatternAndCanonicalRoute() {
        val sourceRoute = route()
        val prepared = assertIs<Outcome.Success<PreparedQuiz>>(
            QuizPreparer(
                generateCoverageRoute = { Outcome.Success(sourceRoute) },
                validateCoverageRoute = { _, _ -> Outcome.Success(Unit) },
            ).prepare("IA"),
        ).value

        assertEquals(sourceRoute.items, prepared.route.items)
        assertEquals(listOf(0, 1, 2, 3, 0, 1, 2, 3, 0, 1), PreparedQuiz.correctOptionSequence)
    }

    @Test
    fun coverageFailureStopsPreparationBeforeAnyTurnGeneration() {
        val error = assertIs<Outcome.Failure<QuizPreparationError>>(
            QuizPreparer(
                generateCoverageRoute = { Outcome.Failure(CoverageRouteGenerationError.BlankTopic) },
                validateCoverageRoute = { _, _ -> Outcome.Success(Unit) },
            ).prepare("IA"),
        ).error

        assertEquals(
            CoverageRouteGenerationError.BlankTopic,
            (error as QuizPreparationError.CoverageRouteGenerationFailed).cause,
        )
    }

    @Test
    fun invalidCoverageRouteSizeIsReported() {
        val shortRoute = CoverageRoute.of(route().items.take(9))
        val error = assertIs<Outcome.Failure<QuizPreparationError>>(
            QuizPreparer(
                generateCoverageRoute = { Outcome.Success(shortRoute) },
                validateCoverageRoute = { _, _ -> Outcome.Success(Unit) },
            ).prepare("IA"),
        ).error

        assertEquals(QuizPreparationError.InvalidCoverageRouteSize(9), error)
    }

    @Test
    fun validationRunsAfterSuccessfulGenerationWithSameTopicAndRoute() {
        val generatedRoute = route()
        val events = mutableListOf<String>()
        val result = QuizPreparer(
            generateCoverageRoute = { topic ->
                events += "generate:$topic"
                Outcome.Success(generatedRoute)
            },
            validateCoverageRoute = { topic, receivedRoute ->
                events += "validate:$topic:${receivedRoute.size}"
                assertEquals(generatedRoute.items, receivedRoute.items)
                Outcome.Success(Unit)
            },
        ).prepare("Astronomía")

        val prepared = assertIs<Outcome.Success<PreparedQuiz>>(result).value
        assertEquals(listOf("generate:Astronomía", "validate:Astronomía:10"), events)
        assertEquals(generatedRoute.items, prepared.route.items)
    }

    @Test
    fun validationRejectionStopsPreparation() {
        val error = assertIs<Outcome.Failure<QuizPreparationError>>(
            QuizPreparer(
                generateCoverageRoute = { Outcome.Success(route()) },
                validateCoverageRoute = {
                    _, _ -> Outcome.Failure(CoverageRouteValidationError.RouteRejected(listOf("Grupo inconsistente")))
                },
            ).prepare("IA"),
        ).error

        assertEquals(
            QuizPreparationError.CoverageRouteValidationFailed(
                CoverageRouteValidationError.RouteRejected(listOf("Grupo inconsistente")),
            ),
            error,
        )
    }

    @Test
    fun generationFailurePreventsValidationCall() {
        var validationCalls = 0
        QuizPreparer(
            generateCoverageRoute = { Outcome.Failure(CoverageRouteGenerationError.InvalidGeneratedRoute) },
            validateCoverageRoute = { _, _ ->
                validationCalls += 1
                Outcome.Success(Unit)
            },
        ).prepare("IA")

        assertEquals(0, validationCalls)
    }
}
