package dev.magullodev.quiz10.systems.quiz10.session

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.preparation.PreparedQuiz
import dev.magullodev.quiz10.systems.quiz10.question.QuizQuestion

class Quiz10Flow(
    private val preparedQuiz: PreparedQuiz,
) {
    private var session: QuizSession? = null
    private var currentState: Quiz10FlowState? = null

    val state: Quiz10FlowState?
        get() = currentState

    fun start(): Quiz10FlowState.Question {
        val newSession = QuizSession.start(preparedQuiz.route)
        session = newSession

        val questionNumber = newSession.currentQuestionNumber ?: error("Prepared quiz unexpectedly has no current question")
        val question = preparedQuiz.questions[questionNumber - 1]
        val current = Quiz10FlowState.Question(
            topic = preparedQuiz.topic,
            questionNumber = questionNumber,
            totalQuestions = preparedQuiz.questions.size,
            area = preparedQuiz.route.items[questionNumber - 1].area,
            question = question,
            answeredQuestions = newSession.answeredQuestions,
            correctAnswers = newSession.correctAnswers,
        )
        currentState = current
        return current
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

    fun advance(): Outcome<Quiz10FlowState, Nothing> {
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
        val nextQuestion = preparedQuiz.questions[nextQuestionNumber - 1]
        val nextState = Quiz10FlowState.Question(
            topic = answeredState.topic,
            questionNumber = nextQuestionNumber,
            totalQuestions = answeredState.totalQuestions,
            area = preparedQuiz.route.items[nextQuestionNumber - 1].area,
            question = nextQuestion,
            answeredQuestions = sessionSnapshot.answeredQuestions,
            correctAnswers = sessionSnapshot.correctAnswers,
        )
        currentState = nextState
        return Outcome.Success(nextState)
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
