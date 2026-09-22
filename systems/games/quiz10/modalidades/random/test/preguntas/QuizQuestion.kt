package dev.magullodev.aiapps.systems.games.quiz10.random.test.preguntas

import java.util.Collections

class QuizQuestion(
    val text: String,
    options: List<String>,
    feedbackByOption: List<String>,
    val correctOptionIndex: Int,
) {
    val options: List<String> = Collections.unmodifiableList(options.toList())
    private val feedbackByOption: List<String> = Collections.unmodifiableList(feedbackByOption.toList())

    init {
        require(text.isNotBlank()) { "Question text must not be blank" }
        require(this.options.size == 4) { "Question must have exactly four options" }
        require(this.options.all { it.isNotBlank() }) { "Question options must not be blank" }
        require(this.feedbackByOption.size == 4) { "Question feedback must have exactly four entries" }
        require(this.feedbackByOption.all { it.isNotBlank() }) { "Question feedback must not be blank" }
        require(correctOptionIndex in 0..3) { "Correct option index must be between 0 and 3" }
    }

    fun isCorrect(optionIndex: Int): Boolean {
        require(optionIndex in 0..3) { "Option index must be between 0 and 3" }
        return optionIndex == correctOptionIndex
    }

    fun feedbackFor(optionIndex: Int): String {
        require(optionIndex in 0..3) { "Option index must be between 0 and 3" }
        return feedbackByOption[optionIndex]
    }
}
