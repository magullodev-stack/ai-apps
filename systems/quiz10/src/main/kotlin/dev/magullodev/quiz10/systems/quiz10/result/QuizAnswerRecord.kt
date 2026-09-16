package dev.magullodev.quiz10.systems.quiz10.result

import dev.magullodev.quiz10.systems.quiz10.question.QuizQuestion

class QuizAnswerRecord(
    val questionNumber: Int,
    val area: String,
    val question: QuizQuestion,
    val selectedOptionIndex: Int,
) {
    val isCorrect: Boolean
        get() = question.isCorrect(selectedOptionIndex)

    val selectedAnswer: String
        get() = question.options[selectedOptionIndex]

    val correctAnswer: String
        get() = question.options[question.correctOptionIndex]

    init {
        require(questionNumber in 1..10) { "Question number must be between 1 and 10" }
        require(area.isNotBlank()) { "Area must not be blank" }
        require(selectedOptionIndex in 0..3) { "Selected option index must be between 0 and 3" }
    }
}
