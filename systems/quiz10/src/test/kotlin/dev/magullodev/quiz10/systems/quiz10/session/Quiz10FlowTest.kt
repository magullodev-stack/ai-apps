package dev.magullodev.quiz10.systems.quiz10.session

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageDifficulty
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRoute
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRouteItem
import dev.magullodev.quiz10.systems.quiz10.preparation.PreparedQuiz
import dev.magullodev.quiz10.systems.quiz10.question.QuizQuestion
import kotlin.test.Test
import kotlin.test.assertEquals
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

    private fun preparedQuiz() = PreparedQuiz(
        topic = "IA",
        route = route(),
        questions = List(10) { index ->
            QuizQuestion(
                text = "Question $index",
                options = listOf("Option 0", "Option 1", "Option 2", "Option 3"),
                correctOptionIndex = PreparedQuiz.correctOptionSequence[index],
            )
        },
    )

    @Test
    fun startQuestionFromPreparedQuiz() {
        val flow = Quiz10Flow(preparedQuiz())

        val started = flow.start()

        assertEquals("IA", started.topic)
        assertEquals(1, started.questionNumber)
        assertEquals(10, started.totalQuestions)
        assertEquals(0, started.answeredQuestions)
        assertEquals(0, started.correctAnswers)
        assertEquals(0, started.question.correctOptionIndex)
    }

    @Test
    fun questionAnsweredToQuestionTransitionWorks() {
        val flow = Quiz10Flow(preparedQuiz())
        val started = flow.start()
        val answered = flow.answer(started.question.correctOptionIndex)

        assertEquals(1, answered.answeredQuestions)
        assertEquals(1, answered.correctAnswers)
        assertTrue(answered.isCorrect)

        val advanced = assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value
        assertIs<Quiz10FlowState.Question>(advanced)
        assertEquals(2, advanced.questionNumber)
    }

    @Test
    fun tenthAnswerEndsGame() {
        val flow = Quiz10Flow(preparedQuiz())
        flow.start()
        repeat(9) {
            val state = assertIs<Quiz10FlowState.Question>(flow.state)
            flow.answer(state.question.correctOptionIndex)
            assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance())
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
    fun preparedQuestionsAreUsedWithoutAnyGenerationDuringGame() {
        val flow = Quiz10Flow(preparedQuiz())
        flow.start()

        for (questionNumber in 1..10) {
            val state = assertIs<Quiz10FlowState.Question>(flow.state)
            assertEquals(questionNumber, state.questionNumber)
            assertEquals(PreparedQuiz.correctOptionSequence[questionNumber - 1], state.question.correctOptionIndex)
            val answered = flow.answer(state.question.correctOptionIndex)
            if (questionNumber < 10) {
                val next = assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value
                assertIs<Quiz10FlowState.Question>(next)
            } else {
                val finished = assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value
                assertIs<Quiz10FlowState.Finished>(finished)
            }
        }
    }
}
