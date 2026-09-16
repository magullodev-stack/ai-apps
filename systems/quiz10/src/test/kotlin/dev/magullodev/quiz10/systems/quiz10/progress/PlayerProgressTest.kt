package dev.magullodev.quiz10.systems.quiz10.progress

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class PlayerProgressTest {
    @Test
    fun createsWithNormalizedValidName() {
        val progress = PlayerProgress.start("  Ada  ")

        assertEquals("Ada", progress.playerName)
    }

    @Test
    fun rejectsBlankName() {
        for (blank in listOf("", " ", "\t\n")) {
            assertFailsWith<IllegalArgumentException> { PlayerProgress.start(blank) }
        }
    }

    @Test
    fun startsAtZero() {
        val progress = PlayerProgress.start("Ada")

        assertEquals(0, progress.answeredQuestions)
        assertEquals(0, progress.correctAnswers)
        assertEquals(0, progress.incorrectAnswers)
        assertEquals(0, progress.accuracyPercent)
        assertEquals(0, progress.stars)
    }

    @Test
    fun accumulatesCorrectAndIncorrectAnswers() {
        val updated = PlayerProgress.start("Ada")
            .recordQuiz(7)
            .recordQuiz(8)

        assertEquals(20, updated.answeredQuestions)
        assertEquals(15, updated.correctAnswers)
        assertEquals(5, updated.incorrectAnswers)
    }

    @Test
    fun computesAccumulatedAccuracyPercent() {
        val updated = PlayerProgress.start("Ada")
            .recordQuiz(7)
            .recordQuiz(8)

        assertEquals(75, updated.accuracyPercent)
    }

    @Test
    fun lessThanTenDoesNotGrantStar() {
        val updated = PlayerProgress.start("Ada").recordQuiz(9)

        assertEquals(0, updated.stars)
    }

    @Test
    fun tenOutOfTenGrantsExactlyOneStar() {
        val updated = PlayerProgress.start("Ada").recordQuiz(10)

        assertEquals(1, updated.stars)
    }

    @Test
    fun starsAccumulateOnlyForPerfectScores() {
        val updated = PlayerProgress.start("Ada")
            .recordQuiz(10)
            .recordQuiz(6)
            .recordQuiz(10)
            .recordQuiz(9)

        assertEquals(40, updated.answeredQuestions)
        assertEquals(35, updated.correctAnswers)
        assertEquals(5, updated.incorrectAnswers)
        assertEquals(87, updated.accuracyPercent)
        assertEquals(2, updated.stars)
    }

    @Test
    fun rejectsOutOfRangeQuizResults() {
        val progress = PlayerProgress.start("Ada")

        assertFailsWith<IllegalArgumentException> { progress.recordQuiz(-1) }
        assertFailsWith<IllegalArgumentException> { progress.recordQuiz(11) }
    }
}
