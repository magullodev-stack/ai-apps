package dev.magullodev.aiapps.systems.games.quiz10.random.test.preguntas

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageRouteItem
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.PreparedQuiz
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.PreparedQuizQuestion
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.luna.QuizTurnGenerationError
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preguntas.QuizQuestion
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preguntas.QuizAnswerRecord
import java.util.Collections

class Quiz10Flow(
    private val preparedQuiz: PreparedQuiz,
    private val generateTurn: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError>,
) {
    private var session: QuizSession? = null
    private var currentState: Quiz10FlowState? = null
    private val answerRecords = mutableListOf<QuizAnswerRecord>()

    val state: Quiz10FlowState?
        get() = currentState

    fun start(): Outcome<Quiz10FlowState.Question, Quiz10FlowTransitionError> {
        val newSession = QuizSession.start(preparedQuiz.route)
        session = newSession
        answerRecords.clear()

        val questionNumber = newSession.currentQuestionNumber ?: error("Prepared quiz unexpectedly has no current question")
        val question = when (val resolved = resolveQuestion(questionNumber)) {
            is Outcome.Success -> resolved.value
            is Outcome.Failure -> {
                return Outcome.Failure(
                    Quiz10FlowTransitionError.TurnGenerationFailed(
                        questionNumber = questionNumber,
                        cause = resolved.error,
                    ),
                )
            }
        }
        val current = Quiz10FlowState.Question(
            topic = preparedQuiz.topic,
            questionNumber = questionNumber,
            totalQuestions = preparedQuiz.route.size,
            area = preparedQuiz.route.items[questionNumber - 1].area,
            question = question,
            answeredQuestions = newSession.answeredQuestions,
            correctAnswers = newSession.correctAnswers,
        )
        currentState = current
        return Outcome.Success(current)
    }

    fun answer(selectedOptionIndex: Int): Quiz10FlowState.Answered {
        val questionState = currentState as? Quiz10FlowState.Question
            ?: throw IllegalStateException("Quiz answer can only be recorded from Question state")
        require(selectedOptionIndex in 0..3) { "Selected option index must be between 0 and 3" }

        val sessionSnapshot = session ?: throw IllegalStateException("Quiz session was not initialized")
        val isCorrect = questionState.question.isCorrect(selectedOptionIndex)
        val updatedSession = sessionSnapshot.recordAnswer(isCorrect)
        session = updatedSession
        answerRecords += QuizAnswerRecord(
            questionNumber = questionState.questionNumber,
            area = questionState.area,
            question = questionState.question,
            selectedOptionIndex = selectedOptionIndex,
        )

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

    fun advance(): Outcome<Quiz10FlowState, Quiz10FlowTransitionError> {
        val answeredState = currentState as? Quiz10FlowState.Answered
            ?: throw IllegalStateException("Quiz advance can only be used from Answered state")

        val sessionSnapshot = session ?: throw IllegalStateException("Quiz session not initialized")
        if (answeredState.isLastQuestion || sessionSnapshot.isFinished) {
            val answersSnapshot = Collections.unmodifiableList(answerRecords.toList())
            val finishedState = Quiz10FlowState.Finished(
                topic = answeredState.topic,
                totalQuestions = answeredState.totalQuestions,
                correctAnswers = answeredState.correctAnswers,
                answers = answersSnapshot,
                failedAnswers = Collections.unmodifiableList(answersSnapshot.filter { !it.isCorrect }),
            )
            currentState = finishedState
            return Outcome.Success(finishedState)
        }

        val nextQuestionNumber = sessionSnapshot.currentQuestionNumber
            ?: throw IllegalStateException("Quiz session has no pending question")
        val nextQuestion = when (val resolved = resolveQuestion(nextQuestionNumber)) {
            is Outcome.Success -> resolved.value
            is Outcome.Failure -> {
                return Outcome.Failure(
                    Quiz10FlowTransitionError.TurnGenerationFailed(
                        questionNumber = nextQuestionNumber,
                        cause = resolved.error,
                    ),
                )
            }
        }
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

    private fun resolveQuestion(questionNumber: Int): Outcome<QuizQuestion, QuizTurnGenerationError> {
        val prebuilt = preparedQuiz.questions
        if (prebuilt != null) {
            return Outcome.Success(toQuizQuestion(prebuilt[questionNumber - 1], questionNumber))
        }

        val item = preparedQuiz.route.items[questionNumber - 1]
        val correctOptionIndex = PreparedQuiz.correctOptionSequence[questionNumber - 1]
        return generateTurn(item, correctOptionIndex)
    }

    private fun toQuizQuestion(prepared: PreparedQuizQuestion, questionNumber: Int): QuizQuestion {
        val correctOptionIndex = PreparedQuiz.correctOptionSequence[questionNumber - 1]
        val options = prepared.distractors.toMutableList()
        options.add(correctOptionIndex, prepared.answer)
        val feedback = MutableList(4) { "Respuesta correcta: ${prepared.answer}" }
        feedback[correctOptionIndex] = "Correcto. Respuesta: ${prepared.answer}"
        return QuizQuestion(
            text = prepared.question,
            options = options,
            feedbackByOption = feedback,
            correctOptionIndex = correctOptionIndex,
        )
    }
}

sealed interface Quiz10FlowTransitionError {
    data class TurnGenerationFailed(
        val questionNumber: Int,
        val cause: QuizTurnGenerationError,
    ) : Quiz10FlowTransitionError
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
        val answers: List<QuizAnswerRecord>,
        val failedAnswers: List<QuizAnswerRecord>,
    ) : Quiz10FlowState
}
