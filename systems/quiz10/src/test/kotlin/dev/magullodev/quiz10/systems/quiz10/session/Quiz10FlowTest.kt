package dev.magullodev.quiz10.systems.quiz10.session

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageDifficulty
import dev.magullodev.quiz10.systems.quiz10.coverage.CoveragePlanningError
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRoute
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRouteItem
import dev.magullodev.quiz10.systems.quiz10.question.QuestionGenerationError
import dev.magullodev.quiz10.systems.quiz10.question.QuizQuestion
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertIs
import kotlin.test.assertTrue

class Quiz10FlowTest {
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

    private fun questionFor(index: Int) = QuizQuestion(
        text = "Question $index",
        options = listOf("Option 0", "Option 1", "Option 2", "Option 3"),
        correctOptionIndex = index,
    )

    @Test
    fun startGeneratesFirstQuestionWithCorrectIndex() {
        val flow = Quiz10Flow(
            planTopic = { Outcome.Success(route()) },
            generateQuestion = { _, correctOptionIndex ->
                Outcome.Success(questionFor(correctOptionIndex))
            },
        )

        val start = flow.start("IA")

        val state = assertIs<Outcome.Success<Quiz10FlowState>>(start).value
        val question = assertIs<Quiz10FlowState.Question>(state)
        assertEquals("IA", question.topic)
        assertEquals(1, question.questionNumber)
        assertEquals(10, question.totalQuestions)
        assertEquals(0, question.question.correctOptionIndex)
        assertEquals(0, question.answeredQuestions)
        assertEquals(0, question.correctAnswers)
    }

    @Test
    fun correctAndWrongAnswerUpdateMetrics() {
        val flow = Quiz10Flow(
            planTopic = { Outcome.Success(route()) },
            generateQuestion = { _, correctOptionIndex -> Outcome.Success(questionFor(correctOptionIndex)) },
        )

        flow.start("IA")

        val correct = flow.answer(0)
        assertTrue(correct.isCorrect)
        assertEquals(1, correct.answeredQuestions)
        assertEquals(1, correct.correctAnswers)

        assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance())
        val next = assertIs<Quiz10FlowState.Question>(flow.state)
        val wrong = flow.answer((next.question.correctOptionIndex + 1) % 4)

        assertTrue(!wrong.isCorrect)
        assertEquals(2, wrong.answeredQuestions)
        assertEquals(1, wrong.correctAnswers)
        assertEquals(next.questionNumber, wrong.questionNumber)
    }

    @Test
    fun transitionsQuestionToAnsweredToQuestion() {
        val flow = Quiz10Flow(
            planTopic = { Outcome.Success(route()) },
            generateQuestion = { _, correctOptionIndex -> Outcome.Success(questionFor(correctOptionIndex)) },
        )

        val started = assertIs<Outcome.Success<Quiz10FlowState>>(flow.start("IA")).value
        val question = assertIs<Quiz10FlowState.Question>(started)
        val answered = flow.answer(0)

        assertEquals(question.questionNumber, answered.questionNumber)
        assertEquals(question.totalQuestions, answered.totalQuestions)
        assertEquals(1, answered.answeredQuestions)
        assertEquals(1, answered.correctAnswers)

        val next = assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value
        assertIs<Quiz10FlowState.Question>(next)
        assertEquals(2, next.questionNumber)
    }

    @Test
    fun correctOptionSequenceMatchesPattern() {
        val indices = mutableListOf<Int>()
        val flow = Quiz10Flow(
            planTopic = { Outcome.Success(route()) },
            generateQuestion = { _, correctOptionIndex ->
                indices += correctOptionIndex
                Outcome.Success(questionFor(correctOptionIndex))
            },
        )

        var outcome = flow.start("IA")
        assertIs<Outcome.Success<Quiz10FlowState>>(outcome)
        for (questionNumber in 1..10) {
            val state = assertIs<Quiz10FlowState.Question>(flow.state)
            assertEquals(listOf(0, 1, 2, 3, 0, 1, 2, 3, 0, 1)[questionNumber - 1], state.question.correctOptionIndex)
            val answered = flow.answer(state.question.correctOptionIndex)
            if (questionNumber < 10) {
                val next = assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value
                assertIs<Quiz10FlowState.Question>(next)
            } else {
                val finished = assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value
                assertIs<Quiz10FlowState.Finished>(finished)
            }
        }

        assertEquals(listOf(0, 1, 2, 3, 0, 1, 2, 3, 0, 1), indices)
    }

    @Test
    fun tenthAnswerTransitionsToFinishedWithoutExtraGeneration() {
        val flow = Quiz10Flow(
            planTopic = { Outcome.Success(route()) },
            generateQuestion = { _, correctOptionIndex -> Outcome.Success(questionFor(correctOptionIndex)) },
        )

        flow.start("IA")
        repeat(9) {
            val question = assertIs<Quiz10FlowState.Question>(flow.state)
            flow.answer(question.question.correctOptionIndex)
            val next = assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value
            assertIs<Quiz10FlowState.Question>(next)
        }

        val finalQuestion = assertIs<Quiz10FlowState.Question>(flow.state)
        val answered = flow.answer(finalQuestion.question.correctOptionIndex)
        assertTrue(answered.isLastQuestion)

        val finished = assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value
        assertIs<Quiz10FlowState.Finished>(finished)
        assertEquals(10, finished.totalQuestions)
        assertEquals(10, finished.correctAnswers)
    }

    @Test
    fun propagatesPlanningAndGenerationFailuresDifferently() {
        val planningFailure = Quiz10Flow(
            planTopic = { Outcome.Failure(CoveragePlanningError.BlankTopic) },
            generateQuestion = { _, _ -> Outcome.Success(questionFor(0)) },
        )
        val planning = planningFailure.start("")
        val errorPlanning = assertIs<Outcome.Failure<Quiz10FlowError>>(planning).error
        assertIs<Quiz10FlowError.PlanningFailed>(errorPlanning)
        assertEquals(CoveragePlanningError.BlankTopic, errorPlanning.cause)

        val generationFailure = Quiz10Flow(
            planTopic = { Outcome.Success(route()) },
            generateQuestion = { _, _ -> Outcome.Failure(QuestionGenerationError.InvalidGeneratedQuestion) },
        )
        val generation = generationFailure.start("IA")
        val errorGeneration = assertIs<Outcome.Failure<Quiz10FlowError>>(generation).error
        assertIs<Quiz10FlowError.QuestionGenerationFailed>(errorGeneration)
        assertEquals(QuestionGenerationError.InvalidGeneratedQuestion, errorGeneration.cause)
    }

    @Test
    fun preservesAnsweredStateIfAdvanceGenerationFails() {
        val flow = Quiz10Flow(
            planTopic = { Outcome.Success(route()) },
            generateQuestion = { _, correctOptionIndex ->
                if (correctOptionIndex == 1) {
                    Outcome.Failure(QuestionGenerationError.InvalidGeneratedQuestion)
                } else {
                    Outcome.Success(questionFor(correctOptionIndex))
                }
            },
        )

        flow.start("IA")
        val answered = flow.answer(0)

        val result = flow.advance()
        assertIs<Outcome.Failure<Quiz10FlowError>>(result)
        val current = assertIs<Quiz10FlowState.Answered>(flow.state)
        assertEquals(answered.questionNumber, current.questionNumber)
        assertEquals(answered.selectedOptionIndex, current.selectedOptionIndex)
        assertEquals(answered.answeredQuestions, current.answeredQuestions)
        assertEquals(answered.correctAnswers, current.correctAnswers)
    }
}
