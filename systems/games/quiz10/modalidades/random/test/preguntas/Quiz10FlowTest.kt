package dev.magullodev.aiapps.systems.games.quiz10.random.test.preguntas

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageRouteItem
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.PreparedQuiz
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.PreparedQuizQuestion
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

    private fun preparedQuiz() = PreparedQuiz(
        topic = "IA",
        route = route(),
        questions = List(10) { index ->
            PreparedQuizQuestion("Question $index", "Answer $index", listOf("A$index", "B$index", "C$index"))
        },
    )

    @Test
    fun startPresentsFirstPreparedQuestion() {
        val flow = Quiz10Flow(preparedQuiz())
        val started = assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start()).value
        assertEquals("IA", started.topic)
        assertEquals(1, started.questionNumber)
        assertEquals(10, started.totalQuestions)
        assertEquals(0, started.answeredQuestions)
        assertEquals(0, started.correctAnswers)
        assertEquals("Question 0", started.question.text)
        assertEquals(PreparedQuiz.correctOptionSequence[0], started.question.correctOptionIndex)
    }

    @Test
    fun answerThenAdvancePresentsNextPreparedQuestion() {
        val flow = Quiz10Flow(preparedQuiz())
        val started = assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start()).value
        val answered = flow.answer(started.question.correctOptionIndex)
        assertEquals(1, answered.answeredQuestions)
        assertEquals(1, answered.correctAnswers)
        assertTrue(answered.isCorrect)
        val advanced = assertIs<Quiz10FlowState.Question>(assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value)
        assertEquals(2, advanced.questionNumber)
        assertEquals("Question 1", advanced.question.text)
        assertEquals(PreparedQuiz.correctOptionSequence[1], advanced.question.correctOptionIndex)
    }

    @Test
    fun preparedQuestionsRemainInOrder() {
        val flow = Quiz10Flow(preparedQuiz())
        var current = assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start()).value
        for (number in 1..6) {
            assertEquals(number, current.questionNumber)
            assertEquals("Question ${number - 1}", current.question.text)
            assertEquals("History", current.area)
            if (number < 6) {
                flow.answer(current.question.correctOptionIndex)
                current = assertIs<Quiz10FlowState.Question>(assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value)
            }
        }
    }

    @Test
    fun preparedQuestionsKeepCanonicalAnswerAndDeterministicCorrectOptionSequence() {
        val flow = Quiz10Flow(preparedQuiz())
        var state = assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start()).value
        for (number in 1..10) {
            val expectedIndex = PreparedQuiz.correctOptionSequence[number - 1]
            assertEquals(expectedIndex, state.question.correctOptionIndex)
            assertEquals("Answer ${number - 1}", state.question.options[expectedIndex])
            flow.answer((expectedIndex + 1) % 4)
            if (number < 10) {
                state = assertIs<Quiz10FlowState.Question>(assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value)
            } else {
                val finished = assertIs<Quiz10FlowState.Finished>(assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value)
                assertEquals(10, finished.failedAnswers.size)
            }
        }
    }

    @Test
    fun eachAnswerCreatesRecordWithExpectedQuestionAreaQuestionAndSelection() {
        val flow = Quiz10Flow(preparedQuiz())
        val started = assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start()).value
        val selected = (started.question.correctOptionIndex + 1) % 4
        flow.answer(selected)
        val answered = assertIs<Quiz10FlowState.Answered>(flow.state)
        assertEquals(1, answered.questionNumber)
        assertEquals(selected, answered.selectedOptionIndex)
        repeat(9) {
            assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance())
            flow.answer(assertIs<Quiz10FlowState.Question>(flow.state).question.correctOptionIndex)
        }
        val finished = assertIs<Quiz10FlowState.Finished>(assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value)
        val record = finished.answers.first()
        assertEquals(1, record.questionNumber)
        assertEquals(started.area, record.area)
        assertEquals(started.question, record.question)
        assertEquals(selected, record.selectedOptionIndex)
        assertEquals(started.question.options[selected], record.selectedAnswer)
        assertEquals(started.question.options[started.question.correctOptionIndex], record.correctAnswer)
    }

    @Test
    fun tenthAnswerEndsGameWithoutAnEleventhQuestion() {
        val flow = Quiz10Flow(preparedQuiz())
        assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start())
        repeat(9) {
            flow.answer(assertIs<Quiz10FlowState.Question>(flow.state).question.correctOptionIndex)
            assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance())
        }
        val last = assertIs<Quiz10FlowState.Question>(flow.state)
        assertTrue(flow.answer(last.question.correctOptionIndex).isLastQuestion)
        val finished = assertIs<Quiz10FlowState.Finished>(assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value)
        assertEquals(10, finished.totalQuestions)
        assertEquals(10, finished.correctAnswers)
        assertEquals((1..10).toList(), finished.answers.map { it.questionNumber })
        assertTrue(finished.failedAnswers.isEmpty())
        assertFailsWith<IllegalStateException> { flow.advance() }
    }

    @Test
    fun missingPreparedQuestionsFailWithoutGeneratingATurn() {
        val flow = Quiz10Flow(PreparedQuiz(topic = "IA", route = route()))
        val error = assertIs<Outcome.Failure<Quiz10FlowTransitionError>>(flow.start()).error
        assertEquals(Quiz10FlowTransitionError.MissingPreparedQuestion(1), error)
    }

    @Test
    fun incompleteQuestionsAreRejectedBeforePlaying() {
        assertFailsWith<IllegalArgumentException> {
            PreparedQuiz(topic = "IA", route = route(), questions = preparedQuiz().questions!!.take(3))
        }
    }

    @Test
    fun failedAnswersContainOnlyWrongAnswers() {
        val flow = Quiz10Flow(preparedQuiz())
        assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start())
        for (number in 1..10) {
            val state = assertIs<Quiz10FlowState.Question>(flow.state)
            val correct = state.question.correctOptionIndex
            flow.answer(if (number % 2 == 0) correct else (correct + 1) % 4)
            if (number < 10) assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance())
        }
        val finished = assertIs<Quiz10FlowState.Finished>(assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value)
        assertEquals(10, finished.answers.size)
        assertEquals(listOf(1, 3, 5, 7, 9), finished.failedAnswers.map { it.questionNumber })
        assertTrue(finished.failedAnswers.all { !it.isCorrect })
    }

    @Test
    fun finishedHistorySnapshotsCannotBeMutated() {
        val flow = Quiz10Flow(preparedQuiz())
        assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start())
        repeat(10) { index ->
            val correct = assertIs<Quiz10FlowState.Question>(flow.state).question.correctOptionIndex
            flow.answer(if (index == 0) (correct + 1) % 4 else correct)
            if (index < 9) assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance())
        }
        val finished = assertIs<Quiz10FlowState.Finished>(assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value)
        assertFailsWith<UnsupportedOperationException> { (finished.answers as MutableList).clear() }
        assertFailsWith<UnsupportedOperationException> { (finished.failedAnswers as MutableList).clear() }
        assertEquals(10, finished.answers.size)
        assertEquals(1, finished.failedAnswers.size)
    }
}
