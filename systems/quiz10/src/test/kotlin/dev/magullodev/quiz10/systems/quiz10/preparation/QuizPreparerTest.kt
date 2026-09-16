package dev.magullodev.quiz10.systems.quiz10.preparation

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageDifficulty
import dev.magullodev.quiz10.systems.quiz10.coverage.CoveragePlanningError
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRoute
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRouteItem
import dev.magullodev.quiz10.systems.quiz10.question.QuestionGenerationError
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
            area = "History",
            group = "Ancient Rome",
            referent = "Referent $index",
            knowledge = "Knowledge $index",
            answer = "Answer $index",
        )
    })

    private fun generatedQuestionFor(index: Int) = QuizQuestion(
        text = "Question $index",
        options = listOf("Option 0", "Option 1", "Option 2", "Option 3"),
        feedbackByOption = listOf("Feedback 0", "Feedback 1", "Feedback 2", "Feedback 3"),
        correctOptionIndex = index,
    )

    @Test
    fun plansOnceAndPreparesExactlyTenQuestions() {
        var planCalls = 0
        val flow = QuizPreparer(
            planTopic = {
                planCalls += 1
                Outcome.Success(route())
            },
            generateQuestion = { item, correctOptionIndex ->
                Outcome.Success(generatedQuestionFor(correctOptionIndex))
            },
        )

        val prepared = assertIs<Outcome.Success<PreparedQuiz>>(flow.prepare("IA")).value

        assertEquals(1, planCalls)
        assertEquals(10, prepared.route.size)
        assertEquals(10, prepared.questions.size)
        assertEquals(listOf(0, 1, 2, 3, 0, 1, 2, 3, 0, 1), prepared.questions.map { it.correctOptionIndex })
    }

    @Test
    fun failsPlanningBeforeAnyGeneration() {
        val flow = QuizPreparer(
            planTopic = { Outcome.Failure(CoveragePlanningError.BlankTopic) },
            generateQuestion = { _, _ -> Outcome.Success(generatedQuestionFor(0)) },
        )

        val error = assertIs<Outcome.Failure<QuizPreparationError>>(flow.prepare("IA")).error
        assertEquals(CoveragePlanningError.BlankTopic, (error as QuizPreparationError.PlanningFailed).cause)
    }

    @Test
    fun failsGenerationWithQuestionPosition() {
        val flow = QuizPreparer(
            planTopic = { Outcome.Success(route()) },
            generateQuestion = { _, correctOptionIndex ->
                if (correctOptionIndex == 2) {
                    Outcome.Failure(QuestionGenerationError.InvalidGeneratedQuestion)
                } else {
                    Outcome.Success(generatedQuestionFor(correctOptionIndex))
                }
            },
        )

        val error = assertIs<Outcome.Failure<QuizPreparationError>>(flow.prepare("IA")).error
        val generationFailure = assertIs<QuizPreparationError.GenerationFailed>(error)
        assertEquals(3, generationFailure.questionNumber)
        assertEquals(QuestionGenerationError.InvalidGeneratedQuestion, generationFailure.cause)
    }

    @Test
    fun returnsNoPreparedQuizWhenGenerationDoesNotCompleteTenQuestions() {
        val flow = QuizPreparer(
            planTopic = { Outcome.Success(route()) },
            generateQuestion = { _, _ -> Outcome.Failure(QuestionGenerationError.InvalidGeneratedQuestion) },
        )

        val result = flow.prepare("IA")
        assertIs<Outcome.Failure<QuizPreparationError>>(result)
    }
}
