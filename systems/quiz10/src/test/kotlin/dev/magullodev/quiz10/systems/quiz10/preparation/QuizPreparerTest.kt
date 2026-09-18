package dev.magullodev.quiz10.systems.quiz10.preparation

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageDifficulty
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRoute
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRouteItem
import dev.magullodev.quiz10.systems.quiz10.coverage.terra.CoverageRouteGenerationError
import dev.magullodev.quiz10.systems.quiz10.preparation.luna.QuizTurnGenerationError
import dev.magullodev.quiz10.systems.quiz10.question.QuizQuestion
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

    private fun turnFor(item: CoverageRouteItem, correctOptionIndex: Int): QuizQuestion {
        val options = mutableListOf("Distractor A ${item.referent}", "Distractor B ${item.referent}", "Distractor C ${item.referent}")
        val feedback = mutableListOf("Feedback A ${item.referent}", "Feedback B ${item.referent}", "Feedback C ${item.referent}")
        options.add(correctOptionIndex, item.answer)
        feedback.add(correctOptionIndex, "Correct ${item.knowledge}")
        return QuizQuestion(
            text = "Question about ${item.referent}",
            options = options,
            feedbackByOption = feedback,
            correctOptionIndex = correctOptionIndex,
        )
    }

    @Test
    fun preparesFromSingleCoverageRouteAndTenTurnGenerations() {
        var coverageCalls = 0
        var turnCalls = 0
        val prepared = assertIs<Outcome.Success<PreparedQuiz>>(
            QuizPreparer(
                generateCoverageRoute = {
                    coverageCalls += 1
                    Outcome.Success(route())
                },
                generateTurn = { item, index ->
                    turnCalls += 1
                    Outcome.Success(turnFor(item, index))
                },
            ).prepare("IA"),
        ).value

        assertEquals(1, coverageCalls)
        assertEquals(10, turnCalls)
        assertEquals(10, prepared.route.size)
        assertEquals(10, prepared.questions.size)
        assertEquals(PreparedQuiz.correctOptionSequence, prepared.questions.map { it.correctOptionIndex })
    }

    @Test
    fun eachTurnUsesCoverageItemAndPreservesCanonicalAnswerAndCorrectIndexPattern() {
        val sourceRoute = route()
        val receivedItems = mutableListOf<CoverageRouteItem>()
        val receivedIndexes = mutableListOf<Int>()

        val prepared = assertIs<Outcome.Success<PreparedQuiz>>(
            QuizPreparer(
                generateCoverageRoute = { Outcome.Success(sourceRoute) },
                generateTurn = { item, index ->
                    receivedItems += item
                    receivedIndexes += index
                    Outcome.Success(turnFor(item, index))
                },
            ).prepare("IA"),
        ).value

        assertEquals(sourceRoute.items, receivedItems)
        assertEquals(PreparedQuiz.correctOptionSequence, receivedIndexes)
        assertEquals(PreparedQuiz.correctOptionSequence, prepared.questions.map { it.correctOptionIndex })

        prepared.questions.forEachIndexed { index, question ->
            val source = sourceRoute.items[index]
            val correctOptionIndex = PreparedQuiz.correctOptionSequence[index]
            assertEquals(source.answer, question.options[correctOptionIndex])
        }
    }

    @Test
    fun coverageFailureStopsPreparationBeforeAnyTurnGeneration() {
        var turnCalls = 0
        val error = assertIs<Outcome.Failure<QuizPreparationError>>(
            QuizPreparer(
                generateCoverageRoute = { Outcome.Failure(CoverageRouteGenerationError.BlankTopic) },
                generateTurn = { _, _ ->
                    turnCalls += 1
                    error("Turn generation must not be called after coverage failure")
                },
            ).prepare("IA"),
        ).error

        assertEquals(0, turnCalls)
        assertEquals(
            CoverageRouteGenerationError.BlankTopic,
            (error as QuizPreparationError.CoverageRouteGenerationFailed).cause,
        )
    }

    @Test
    fun turnFailureStopsPreparationAndPreservesQuestionNumber() {
        val sourceRoute = route()
        var turnCalls = 0
        val error = assertIs<Outcome.Failure<QuizPreparationError>>(
            QuizPreparer(
                generateCoverageRoute = { Outcome.Success(sourceRoute) },
                generateTurn = { item, index ->
                    turnCalls += 1
                    if (turnCalls == 6) {
                        Outcome.Failure(QuizTurnGenerationError.GenerationFailed(AiError.TransportFailure))
                    } else {
                        Outcome.Success(turnFor(item, index))
                    }
                },
            ).prepare("IA"),
        ).error

        assertEquals(6, turnCalls)
        val turnError = error as QuizPreparationError.TurnGenerationFailed
        assertEquals(6, turnError.questionNumber)
        assertEquals(
            QuizTurnGenerationError.GenerationFailed(AiError.TransportFailure),
            turnError.cause,
        )
    }
}
