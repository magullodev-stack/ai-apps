package dev.magullodev.aiapps.systems.games.quiz10.result

import dev.magullodev.aiapps.systems.games.quiz10.question.QuizQuestion
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class QuizAnswerRecordTest {
    private fun question() = QuizQuestion(
        text = "Question",
        options = listOf("A", "B", "C", "D"),
        feedbackByOption = listOf("FA", "FB", "FC", "FD"),
        correctOptionIndex = 2,
    )

    @Test
    fun derivesSelectedAndCorrectAnswersAndCorrectness() {
        val correct = QuizAnswerRecord(
            questionNumber = 3,
            area = "History",
            question = question(),
            selectedOptionIndex = 2,
        )
        val wrong = QuizAnswerRecord(
            questionNumber = 4,
            area = "History",
            question = question(),
            selectedOptionIndex = 0,
        )

        assertTrue(correct.isCorrect)
        assertEquals("C", correct.selectedAnswer)
        assertEquals("C", correct.correctAnswer)

        assertFalse(wrong.isCorrect)
        assertEquals("A", wrong.selectedAnswer)
        assertEquals("C", wrong.correctAnswer)
    }

    @Test
    fun rejectsInvalidQuestionNumber() {
        assertFailsWith<IllegalArgumentException> {
            QuizAnswerRecord(0, "History", question(), 0)
        }
        assertFailsWith<IllegalArgumentException> {
            QuizAnswerRecord(11, "History", question(), 0)
        }
    }

    @Test
    fun rejectsBlankArea() {
        assertFailsWith<IllegalArgumentException> {
            QuizAnswerRecord(1, " ", question(), 0)
        }
    }

    @Test
    fun rejectsInvalidSelectedOptionIndex() {
        assertFailsWith<IllegalArgumentException> {
            QuizAnswerRecord(1, "History", question(), -1)
        }
        assertFailsWith<IllegalArgumentException> {
            QuizAnswerRecord(1, "History", question(), 4)
        }
    }
}
