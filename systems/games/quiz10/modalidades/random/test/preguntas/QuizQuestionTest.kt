package dev.magullodev.aiapps.systems.games.quiz10.random.test.preguntas

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class QuizQuestionTest {
    private val options = listOf("753 BC", "509 BC", "27 BC", "476 AD")
    private val feedback = listOf(
        "753 BC corresponde a la fundación tradicional de Roma.",
        "509 BC corresponde al inicio de la República romana, no a la fundación.",
        "27 BC corresponde al inicio del Principado de Augusto.",
        "476 AD corresponde a la caída del Imperio romano de Occidente.",
    )

    @Test
    fun exposesTextOptionsAndEveryValidCorrectOptionIndex() {
        for (index in 0..3) {
            val question = QuizQuestion("When was Rome founded?", options, feedback, index)

            assertEquals("When was Rome founded?", question.text)
            assertEquals(options, question.options)
            assertEquals(index, question.correctOptionIndex)
        }
    }

    @Test
    fun rejectsBlankText() {
        for (text in listOf("", " ", "\t\n")) {
            assertFailsWith<IllegalArgumentException> { QuizQuestion(text, options, feedback, 0) }
        }
    }

    @Test
    fun rejectsOptionCountsOtherThanFour() {
        for (count in listOf(0, 1, 2, 3, 5)) {
            assertFailsWith<IllegalArgumentException> {
                QuizQuestion("Question?", List(count) { "Option $it" }, feedback, 0)
            }
        }
    }

    @Test
    fun rejectsBlankOptionsAtEveryPosition() {
        for (index in options.indices) {
            for (blank in listOf("", " ", "\t\n")) {
                val invalid = options.toMutableList().apply { this[index] = blank }
                assertFailsWith<IllegalArgumentException> { QuizQuestion("Question?", invalid, feedback, 0) }
            }
        }
    }

    @Test
    fun rejectsFeedbackCountsOtherThanFour() {
        for (count in listOf(0, 1, 2, 3, 5)) {
            assertFailsWith<IllegalArgumentException> {
                QuizQuestion("Question?", options, List(count) { "Feedback $it" }, 0)
            }
        }
    }

    @Test
    fun rejectsBlankFeedbackAtEveryPosition() {
        for (index in feedback.indices) {
            for (blank in listOf("", " ", "\t\n")) {
                val invalid = feedback.toMutableList().apply { this[index] = blank }
                assertFailsWith<IllegalArgumentException> { QuizQuestion("Question?", options, invalid, 0) }
            }
        }
    }

    @Test
    fun rejectsOutOfRangeCorrectOptionIndex() {
        for (index in listOf(Int.MIN_VALUE, -1, 4, Int.MAX_VALUE)) {
            assertFailsWith<IllegalArgumentException> { QuizQuestion("Question?", options, feedback, index) }
        }
    }

    @Test
    fun correctOptionReturnsTrue() {
        for (index in 0..3) {
            val question = QuizQuestion("Question?", options, feedback, index)

            assertTrue(question.isCorrect(index))
        }
    }

    @Test
    fun otherThreeOptionsReturnFalse() {
        for (correctIndex in 0..3) {
            val question = QuizQuestion("Question?", options, feedback, correctIndex)

            for (index in (0..3).filter { it != correctIndex }) {
                assertFalse(question.isCorrect(index))
            }
        }
    }

    @Test
    fun isCorrectRejectsOutOfRangeOptionIndex() {
        val question = QuizQuestion("Question?", options, feedback, 0)

        for (index in listOf(Int.MIN_VALUE, -1, 4, Int.MAX_VALUE)) {
            assertFailsWith<IllegalArgumentException> { question.isCorrect(index) }
        }
    }

    @Test
    fun feedbackForReturnsValuesForEveryValidOptionIndex() {
        val question = QuizQuestion("Question?", options, feedback, 0)

        for (index in 0..3) {
            assertEquals(feedback[index], question.feedbackFor(index))
        }
    }

    @Test
    fun feedbackForRejectsOutOfRangeOptionIndex() {
        val question = QuizQuestion("Question?", options, feedback, 0)

        for (index in listOf(Int.MIN_VALUE, -1, 4, Int.MAX_VALUE)) {
            assertFailsWith<IllegalArgumentException> { question.feedbackFor(index) }
        }
    }

    @Test
    fun optionsRemainValidAfterOriginalListChanges() {
        val original = options.toMutableList()
        val feedbackOriginal = feedback.toMutableList()
        val question = QuizQuestion("Question?", original, feedbackOriginal, 0)

        original[0] = ""
        original.clear()
        feedbackOriginal[0] = ""
        feedbackOriginal.clear()

        assertEquals(options, question.options)
        assertFailsWith<UnsupportedOperationException> { (question.options as MutableList<String>).clear() }
        assertEquals(feedback[0], question.feedbackFor(0))
        assertEquals(options, question.options)
    }
}
