package dev.magullodev.aiapps.systems.games.quiz10.random.test.preguntas

import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageRouteItem
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class QuizSessionTest {
    private fun item(referent: String, difficulty: CoverageDifficulty = CoverageDifficulty.EASY) =
        CoverageRouteItem(
            difficulty = difficulty,
            area = "History",
            group = "Ancient Rome",
            referent = referent,
            knowledge = "Founding year",
            answer = "753 BC",
        )

    private fun routeOf(size: Int): CoverageRoute {
        val difficulties = when (size) {
            10 -> listOf(
                CoverageDifficulty.EASY,
                CoverageDifficulty.EASY,
                CoverageDifficulty.EASY,
                CoverageDifficulty.EASY,
                CoverageDifficulty.MODERATE,
                CoverageDifficulty.MODERATE,
                CoverageDifficulty.MODERATE,
                CoverageDifficulty.HARD,
                CoverageDifficulty.HARD,
                CoverageDifficulty.VERY_HARD,
            )
            else -> List(size) { index ->
                when {
                    index < size / 2 -> CoverageDifficulty.EASY
                    index < size * 3 / 4 -> CoverageDifficulty.MODERATE
                    else -> CoverageDifficulty.HARD
                }
            }
        }
        return CoverageRoute.of(List(size) { index -> item("Referent $index", difficulties[index]) })
    }

    @Test
    fun startsAtFirstQuestionOfTen() {
        val session = QuizSession.start(routeOf(10))

        assertEquals(10, session.totalQuestions)
        assertEquals(0, session.answeredQuestions)
        assertEquals(0, session.correctAnswers)
        assertEquals(1, session.currentQuestionNumber)
        assertEquals(routeOf(10).items.first(), session.currentItem)
        assertFalse(session.isFinished)
    }

    @Test
    fun answeringAdvancesToNextItem() {
        var session = QuizSession.start(routeOf(10))

        session = session.recordAnswer(true)

        assertEquals(1, session.answeredQuestions)
        assertEquals(1, session.correctAnswers)
        assertEquals(2, session.currentQuestionNumber)
        assertEquals(routeOf(10).items[1], session.currentItem)
        assertFalse(session.isFinished)
    }

    @Test
    fun correctAnswerIncrementsScoreAndWrongAnswerDoesNot() {
        val session = QuizSession.start(routeOf(10))

        val correct = session.recordAnswer(true)
        val wrong = correct.recordAnswer(false)

        assertEquals(1, correct.correctAnswers)
        assertEquals(1, wrong.correctAnswers)
        assertEquals(2, wrong.answeredQuestions)
    }

    @Test
    fun progressAndScoreStayConsistentAfterSeveralAnswers() {
        var session = QuizSession.start(routeOf(10))

        val expectedAnswers = listOf(true, false, true, true, false, true, false, true, true, false)
        expectedAnswers.forEachIndexed { index, isCorrect ->
            session = session.recordAnswer(isCorrect)
            assertEquals(index + 1, session.answeredQuestions)
            assertEquals(expectedAnswers.take(index + 1).count { it }, session.correctAnswers)
            if (index < 9) {
                assertEquals(index + 2, session.currentQuestionNumber)
            }
        }

        assertTrue(session.isFinished)
        assertEquals(10, session.answeredQuestions)
        assertEquals(6, session.correctAnswers)
    }

    @Test
    fun finishesAfterTenAnswers() {
        var session = QuizSession.start(routeOf(10))

        repeat(9) { session = session.recordAnswer(true) }
        session = session.recordAnswer(true)

        assertTrue(session.isFinished)
        assertNull(session.currentItem)
        assertNull(session.currentQuestionNumber)
        assertEquals(10, session.answeredQuestions)
        assertEquals(10, session.correctAnswers)
    }

    @Test
    fun rejectsWrongRouteLength() {
        assertFailsWith<IllegalArgumentException> { QuizSession.start(routeOf(9)) }
        assertFailsWith<IllegalArgumentException> { QuizSession.start(routeOf(11)) }
    }

    @Test
    fun rejectsAnsweringAfterFinal() {
        var session = QuizSession.start(routeOf(10))
        repeat(10) { session = session.recordAnswer(true) }

        assertFailsWith<IllegalStateException> { session.recordAnswer(true) }
    }
}
