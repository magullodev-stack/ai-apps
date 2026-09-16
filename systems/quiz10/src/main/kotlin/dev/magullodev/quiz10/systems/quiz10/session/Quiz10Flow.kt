package dev.magullodev.quiz10.systems.quiz10.session

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoveragePlanningError
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRoute
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRouteItem
import dev.magullodev.quiz10.systems.quiz10.question.QuestionGenerationError
import dev.magullodev.quiz10.systems.quiz10.question.QuizQuestion

class Quiz10Flow(
    private val planTopic: (String) -> Outcome<CoverageRoute, CoveragePlanningError>,
    private val generateQuestion: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuestionGenerationError>,
) {
    private var session: QuizSession? = null
    private var currentState: Quiz10FlowState? = null

    val state: Quiz10FlowState?
        get() = currentState

    fun start(topic: String): Outcome<Quiz10FlowState, Quiz10FlowError> {
        val route = when (val outcome = planTopic(topic)) {
            is Outcome.Success -> outcome.value
            is Outcome.Failure -> return Outcome.Failure(Quiz10FlowError.PlanningFailed(outcome.error))
        }

        val newSession = QuizSession.start(route)
        session = newSession

        val item = newSession.currentItem ?: error("Quiz10 route unexpectedly has no current item")
        val questionNumber = newSession.currentQuestionNumber ?: error("Quiz10 route unexpectedly has no current question")
        val correctOptionIndex = correctOptionIndexFor(questionNumber)

        return when (val outcome = generateQuestion(item, correctOptionIndex)) {
            is Outcome.Success -> {
                val questionState = Quiz10FlowState.Question(
                    topic = topic,
                    questionNumber = questionNumber,
                    totalQuestions = newSession.totalQuestions,
                    area = item.area,
                    question = outcome.value,
                    answeredQuestions = newSession.answeredQuestions,
                    correctAnswers = newSession.correctAnswers,
                )
                currentState = questionState
                Outcome.Success(questionState)
            }
            is Outcome.Failure -> {
                currentState = null
                Outcome.Failure(Quiz10FlowError.QuestionGenerationFailed(outcome.error))
            }
        }
    }

    fun answer(selectedOptionIndex: Int): Quiz10FlowState.Answered {
        val questionState = currentState as? Quiz10FlowState.Question
            ?: throw IllegalStateException("Quiz answer can only be recorded from Question state")
        require(selectedOptionIndex in 0..3) { "Selected option index must be between 0 and 3" }

        val sessionSnapshot = session ?: throw IllegalStateException("Quiz session was not initialized")
        val isCorrect = questionState.question.isCorrect(selectedOptionIndex)
        val updatedSession = sessionSnapshot.recordAnswer(isCorrect)
        session = updatedSession

        val answeredState = Quiz10FlowState.Answered(
            topic = questionState.topic,
            questionNumber = questionState.questionNumber,
            totalQuestions = questionState.totalQuestions,
            area = questionState.area,
            question = questionState.question,
            selectedOptionIndex = selectedOptionIndex,
            isCorrect = isCorrect,
            answeredQuestions = updatedSession.answeredQuestions,
            correctAnswers = updatedSession.correctAnswers,
            isLastQuestion = updatedSession.isFinished,
        )
        currentState = answeredState
        return answeredState
    }

    fun advance(): Outcome<Quiz10FlowState, Quiz10FlowError> {
        val answeredState = currentState as? Quiz10FlowState.Answered
            ?: throw IllegalStateException("Quiz advance can only be used from Answered state")

        val sessionSnapshot = session ?: throw IllegalStateException("Quiz session not initialized")
        if (answeredState.isLastQuestion || sessionSnapshot.isFinished) {
            val finishedState = Quiz10FlowState.Finished(
                topic = answeredState.topic,
                totalQuestions = answeredState.totalQuestions,
                correctAnswers = answeredState.correctAnswers,
            )
            currentState = finishedState
            return Outcome.Success(finishedState)
        }

        val nextQuestionNumber = sessionSnapshot.currentQuestionNumber
            ?: throw IllegalStateException("Quiz session has no pending question")
        val nextItem = sessionSnapshot.currentItem
            ?: throw IllegalStateException("Quiz session has no pending item")
        val correctOptionIndex = correctOptionIndexFor(nextQuestionNumber)

        return when (val outcome = generateQuestion(nextItem, correctOptionIndex)) {
            is Outcome.Success -> {
                val nextState = Quiz10FlowState.Question(
                    topic = answeredState.topic,
                    questionNumber = nextQuestionNumber,
                    totalQuestions = answeredState.totalQuestions,
                    area = nextItem.area,
                    question = outcome.value,
                    answeredQuestions = sessionSnapshot.answeredQuestions,
                    correctAnswers = sessionSnapshot.correctAnswers,
                )
                currentState = nextState
                Outcome.Success(nextState)
            }
            is Outcome.Failure -> {
                currentState = answeredState
                Outcome.Failure(Quiz10FlowError.QuestionGenerationFailed(outcome.error))
            }
        }
    }

    private fun correctOptionIndexFor(questionNumber: Int): Int {
        require(questionNumber in 1..10) { "Question number must be between 1 and 10" }
        return correctOptionSequence[questionNumber - 1]
    }

    private companion object {
        private val correctOptionSequence = listOf(0, 1, 2, 3, 0, 1, 2, 3, 0, 1)
    }
}

sealed interface Quiz10FlowState {
    data class Question(
        val topic: String,
        val questionNumber: Int,
        val totalQuestions: Int,
        val area: String,
        val question: QuizQuestion,
        val answeredQuestions: Int,
        val correctAnswers: Int,
    ) : Quiz10FlowState

    data class Answered(
        val topic: String,
        val questionNumber: Int,
        val totalQuestions: Int,
        val area: String,
        val question: QuizQuestion,
        val selectedOptionIndex: Int,
        val isCorrect: Boolean,
        val answeredQuestions: Int,
        val correctAnswers: Int,
        val isLastQuestion: Boolean,
    ) : Quiz10FlowState

    data class Finished(
        val topic: String,
        val totalQuestions: Int,
        val correctAnswers: Int,
    ) : Quiz10FlowState
}

sealed interface Quiz10FlowError {
    data class PlanningFailed(val cause: CoveragePlanningError) : Quiz10FlowError
    data class QuestionGenerationFailed(val cause: QuestionGenerationError) : Quiz10FlowError
}
