package dev.magullodev.quiz10.systems.quiz10.question

import java.util.Collections

class QuizQuestion(
    val text: String,
    options: List<String>,
    val correctOptionIndex: Int,
) {
    val options: List<String> = Collections.unmodifiableList(options.toList())

    init {
        require(text.isNotBlank()) { "Question text must not be blank" }
        require(this.options.size == 4) { "Question must have exactly four options" }
        require(this.options.all { it.isNotBlank() }) { "Question options must not be blank" }
        require(correctOptionIndex in 0..3) { "Correct option index must be between 0 and 3" }
    }

    fun isCorrect(optionIndex: Int): Boolean {
        require(optionIndex in 0..3) { "Option index must be between 0 and 3" }
        return optionIndex == correctOptionIndex
    }
}
