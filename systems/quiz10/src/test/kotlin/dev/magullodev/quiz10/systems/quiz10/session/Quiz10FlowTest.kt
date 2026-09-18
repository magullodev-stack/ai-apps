package dev.magullodev.quiz10.systems.quiz10.session

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageDifficulty
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRoute
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRouteItem
import dev.magullodev.quiz10.systems.quiz10.preparation.PreparedQuiz
import dev.magullodev.quiz10.systems.quiz10.preparation.luna.QuizTurnGenerationError
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

    private fun preparedQuiz() = PreparedQuiz(topic = "IA", route = route())

    private fun generatedQuestion(item: CoverageRouteItem, correctOptionIndex: Int): QuizQuestion {
        val options = mutableListOf("Option A ${item.referent}", "Option B ${item.referent}", "Option C ${item.referent}")
        val feedback = mutableListOf("F A ${item.referent}", "F B ${item.referent}", "F C ${item.referent}")
        options.add(correctOptionIndex, item.answer)
        feedback.add(correctOptionIndex, "Correct ${item.knowledge}")
        return QuizQuestion(
            text = "Question ${item.referent}",
            options = options,
            feedbackByOption = feedback,
            correctOptionIndex = correctOptionIndex,
        )
    }

    @Test
    fun startGeneratesOnlyQuestionOneFromFirstCoverageItem() {
        val calls = mutableListOf<Pair<CoverageRouteItem, Int>>()
        val route = route()
        val flow = Quiz10Flow(preparedQuiz()) { item, index ->
            calls += item to index
            Outcome.Success(generatedQuestion(item, index))
        }

        val started = assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start()).value

        assertEquals("IA", started.topic)
        assertEquals(1, started.questionNumber)
        assertEquals(10, started.totalQuestions)
        assertEquals(0, started.answeredQuestions)
        assertEquals(0, started.correctAnswers)
        assertEquals(PreparedQuiz.correctOptionSequence[0], started.question.correctOptionIndex)
        assertEquals(1, calls.size)
        assertEquals(route.items[0], calls[0].first)
        assertEquals(PreparedQuiz.correctOptionSequence[0], calls[0].second)
    }

    @Test
    fun answerThenAdvanceGeneratesOnlyNextQuestionTurn() {
        val calls = mutableListOf<Pair<CoverageRouteItem, Int>>()
        val route = route()
        val flow = Quiz10Flow(preparedQuiz()) { item, index ->
            calls += item to index
            Outcome.Success(generatedQuestion(item, index))
        }
        val started = assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start()).value
        val answered = flow.answer(started.question.correctOptionIndex)

        assertEquals(1, answered.answeredQuestions)
        assertEquals(1, answered.correctAnswers)
        assertTrue(answered.isCorrect)
        assertEquals(1, calls.size)

        val advanced = assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value
        assertIs<Quiz10FlowState.Question>(advanced)
        assertEquals(2, advanced.questionNumber)
        assertEquals(2, calls.size)
        assertEquals(route.items[1], calls[1].first)
        assertEquals(PreparedQuiz.correctOptionSequence[1], calls[1].second)
    }

    @Test
    fun afterNQuestionsShownThereAreExactlyNTurnGenerationsAndNoFutureRows() {
        val calls = mutableListOf<Pair<CoverageRouteItem, Int>>()
        val route = route()
        val flow = Quiz10Flow(preparedQuiz()) { item, index ->
            calls += item to index
            Outcome.Success(generatedQuestion(item, index))
        }

        var current = assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start()).value
        for (shownQuestions in 1..6) {
            assertEquals(shownQuestions, current.questionNumber)
            assertEquals(shownQuestions, calls.size)
            assertEquals(route.items[shownQuestions - 1], calls.last().first)
            assertEquals(PreparedQuiz.correctOptionSequence[shownQuestions - 1], calls.last().second)

            if (shownQuestions < 6) {
                flow.answer(current.question.correctOptionIndex)
                current = assertIs<Quiz10FlowState.Question>(assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value)
            }
        }
    }

    @Test
    fun generatedQuestionsKeepCanonicalAnswerAndDeterministicCorrectOptionSequence() {
        val route = route()
        val flow = Quiz10Flow(preparedQuiz()) { item, index ->
            Outcome.Success(generatedQuestion(item, index))
        }

        var state = assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start()).value
        for (questionNumber in 1..10) {
            val expectedIndex = PreparedQuiz.correctOptionSequence[questionNumber - 1]
            val expectedAnswer = route.items[questionNumber - 1].answer
            assertEquals(expectedIndex, state.question.correctOptionIndex)
            assertEquals(expectedAnswer, state.question.options[expectedIndex])

            val selectedOptionIndex = (state.question.correctOptionIndex + 1) % 4
            flow.answer(selectedOptionIndex)

            if (questionNumber < 10) {
                state = assertIs<Quiz10FlowState.Question>(assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value)
            } else {
                val finished = assertIs<Quiz10FlowState.Finished>(assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value)
                assertEquals(10, finished.failedAnswers.size)
            }
        }
    }

    @Test
    fun eachAnswerCreatesRecordWithExpectedQuestionAreaQuestionAndSelection() {
        val flow = Quiz10Flow(preparedQuiz()) { item, index ->
            Outcome.Success(generatedQuestion(item, index))
        }
        val started = assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start()).value
        val selectedOptionIndex = (started.question.correctOptionIndex + 1) % 4

        flow.answer(selectedOptionIndex)

        val answeredState = assertIs<Quiz10FlowState.Answered>(flow.state)
        assertEquals(1, answeredState.questionNumber)
        assertEquals(selectedOptionIndex, answeredState.selectedOptionIndex)

        repeat(9) {
            assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance())
            val current = assertIs<Quiz10FlowState.Question>(flow.state)
            flow.answer(current.question.correctOptionIndex)
        }
        val finished = assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value
        val result = assertIs<Quiz10FlowState.Finished>(finished)
        val firstRecord = result.answers.first()

        assertEquals(1, firstRecord.questionNumber)
        assertEquals(started.area, firstRecord.area)
        assertEquals(started.question, firstRecord.question)
        assertEquals(selectedOptionIndex, firstRecord.selectedOptionIndex)
    }

    @Test
    fun tenthAnswerEndsGameWithoutEleventhTurnGeneration() {
        var generationCalls = 0
        val flow = Quiz10Flow(preparedQuiz()) { item, index ->
            generationCalls += 1
            Outcome.Success(generatedQuestion(item, index))
        }
        assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start())
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
        assertEquals(10, finished.answers.size)
        assertEquals((1..10).toList(), finished.answers.map { it.questionNumber })
        assertTrue(finished.failedAnswers.isEmpty())
        assertEquals(10, generationCalls)
    }

    @Test
    fun startFailureKeepsQuestionNumberOne() {
        val flow = Quiz10Flow(preparedQuiz()) { _, _ ->
            Outcome.Failure(QuizTurnGenerationError.GenerationFailed(AiError.TransportFailure))
        }

        val error = assertIs<Outcome.Failure<Quiz10FlowTransitionError>>(flow.start()).error
        val turnError = assertIs<Quiz10FlowTransitionError.TurnGenerationFailed>(error)
        assertEquals(1, turnError.questionNumber)
        assertEquals(
            QuizTurnGenerationError.GenerationFailed(AiError.TransportFailure),
            turnError.cause,
        )
    }

    @Test
    fun advanceFailureKeepsQuestionNumberOfFailedTurn() {
        var generationCalls = 0
        val flow = Quiz10Flow(preparedQuiz()) { item, index ->
            generationCalls += 1
            if (generationCalls == 4) {
                Outcome.Failure(QuizTurnGenerationError.GenerationFailed(AiError.TransportFailure))
            } else {
                Outcome.Success(generatedQuestion(item, index))
            }
        }

        assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start())
        repeat(3) {
            val state = assertIs<Quiz10FlowState.Question>(flow.state)
            flow.answer(state.question.correctOptionIndex)
            if (it < 2) {
                assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance())
            }
        }

        val error = assertIs<Outcome.Failure<Quiz10FlowTransitionError>>(flow.advance()).error
        val turnError = assertIs<Quiz10FlowTransitionError.TurnGenerationFailed>(error)
        assertEquals(4, turnError.questionNumber)
        assertEquals(
            QuizTurnGenerationError.GenerationFailed(AiError.TransportFailure),
            turnError.cause,
        )
    }

    @Test
    fun failedAnswersContainOnlyWrongAnswers() {
        val flow = Quiz10Flow(preparedQuiz()) { item, index ->
            Outcome.Success(generatedQuestion(item, index))
        }
        assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start())

        for (questionNumber in 1..10) {
            val state = assertIs<Quiz10FlowState.Question>(flow.state)
            val isEven = questionNumber % 2 == 0
            val selected = if (isEven) state.question.correctOptionIndex else (state.question.correctOptionIndex + 1) % 4
            flow.answer(selected)
            if (questionNumber < 10) {
                assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance())
            }
        }

        val finished = assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value
        val result = assertIs<Quiz10FlowState.Finished>(finished)

        assertEquals(10, result.answers.size)
        assertEquals(5, result.failedAnswers.size)
        assertTrue(result.failedAnswers.all { !it.isCorrect })
        assertEquals(listOf(1, 3, 5, 7, 9), result.failedAnswers.map { it.questionNumber })
    }

    @Test
    fun finishedAnswersExposeDerivedSelectedAndCorrectTexts() {
        val flow = Quiz10Flow(preparedQuiz()) { item, index ->
            Outcome.Success(generatedQuestion(item, index))
        }
        val started = assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start()).value
        val selectedOptionIndex = (started.question.correctOptionIndex + 1) % 4

        flow.answer(selectedOptionIndex)
        repeat(9) {
            assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance())
            val state = assertIs<Quiz10FlowState.Question>(flow.state)
            flow.answer(state.question.correctOptionIndex)
        }

        val finished = assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value
        val firstFailed = assertIs<Quiz10FlowState.Finished>(finished).failedAnswers.first()

        assertEquals(started.question.options[selectedOptionIndex], firstFailed.selectedAnswer)
        assertEquals(started.question.options[started.question.correctOptionIndex], firstFailed.correctAnswer)
    }

    @Test
    fun finishedHistorySnapshotsCannotBeMutated() {
        val flow = Quiz10Flow(preparedQuiz()) { item, index ->
            Outcome.Success(generatedQuestion(item, index))
        }
        assertIs<Outcome.Success<Quiz10FlowState.Question>>(flow.start())

        repeat(10) { questionIndex ->
            val state = assertIs<Quiz10FlowState.Question>(flow.state)
            flow.answer(if (questionIndex == 0) (state.question.correctOptionIndex + 1) % 4 else state.question.correctOptionIndex)
            if (questionIndex < 9) {
                assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance())
            }
        }

        val finished = assertIs<Quiz10FlowState.Finished>(assertIs<Outcome.Success<Quiz10FlowState>>(flow.advance()).value)

        assertFailsWith<UnsupportedOperationException> {
            (finished.answers as MutableList).clear()
        }
        assertFailsWith<UnsupportedOperationException> {
            (finished.failedAnswers as MutableList).clear()
        }
        assertEquals(10, finished.answers.size)
        assertEquals(1, finished.failedAnswers.size)
    }
}
