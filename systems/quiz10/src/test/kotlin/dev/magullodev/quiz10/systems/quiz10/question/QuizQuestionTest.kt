package dev.magullodev.quiz10.systems.quiz10.question

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class QuizQuestionTest {
    private val options = listOf("753 BC", "509 BC", "27 BC", "476 AD")

    @Test
    fun exposesTextOptionsAndEveryValidCorrectOptionIndex() {
        for (index in 0..3) {
            val question = QuizQuestion("When was Rome founded?", options, index)

            assertEquals("When was Rome founded?", question.text)
            assertEquals(options, question.options)
            assertEquals(index, question.correctOptionIndex)
        }
    }

    @Test
    fun rejectsBlankText() {
        for (text in listOf("", " ", "\t\n")) {
            assertFailsWith<IllegalArgumentException> { QuizQuestion(text, options, 0) }
        }
    }

    @Test
    fun rejectsOptionCountsOtherThanFour() {
        for (count in listOf(0, 1, 2, 3, 5)) {
            assertFailsWith<IllegalArgumentException> { QuizQuestion("Question?", List(count) { "Option $it" }, 0) }
        }
    }

    @Test
    fun rejectsBlankOptionsAtEveryPosition() {
        for (index in options.indices) {
            for (blank in listOf("", " ", "\t\n")) {
                val invalid = options.toMutableList().apply { this[index] = blank }
                assertFailsWith<IllegalArgumentException> { QuizQuestion("Question?", invalid, 0) }
            }
        }
    }

    @Test
    fun rejectsOutOfRangeCorrectOptionIndex() {
        for (index in listOf(Int.MIN_VALUE, -1, 4, Int.MAX_VALUE)) {
            assertFailsWith<IllegalArgumentException> { QuizQuestion("Question?", options, index) }
        }
    }

    @Test
    fun optionsRemainValidAfterOriginalListChanges() {
        val original = options.toMutableList()
        val question = QuizQuestion("Question?", original, 0)

        original[0] = ""
        original.clear()

        assertEquals(options, question.options)
        assertFailsWith<UnsupportedOperationException> { (question.options as MutableList<String>).clear() }
        assertEquals(options, question.options)
    }
}
