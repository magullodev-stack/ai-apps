package dev.magullodev.aiapps.systems.games.quiz10.preparation

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRouteItem
import dev.magullodev.aiapps.systems.games.quiz10.coverage.Quiz10Area
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlan
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlanner
import dev.magullodev.aiapps.systems.games.quiz10.random.test.processing.CoverageQuestionReview
import dev.magullodev.aiapps.systems.games.quiz10.random.test.processing.CoverageQuestionReviewPosition
import kotlin.random.Random
import kotlin.test.*

class CoverageQuestionCompleterTest {
    private val planner = StandardCoveragePlanner(Random(13))

    private fun route(plan: StandardCoveragePlan) = CoverageRoute.of(plan.positions.map {
        CoverageRouteItem(it.difficulty, it.area.label, "Group ${it.position}",
            "Referent ${it.position}", "Knowledge ${it.position}", "Answer ${it.position}")
    })

    private fun validRows() = List(10) {
        CoverageQuestionReviewPosition.Valid("Question $it", "Answer $it", listOf("A$it", "B$it", "C$it"))
    }

    @Test
    fun completesRandomAndSingleAreaPlansInOrder() {
        for (plan in listOf(planner.random(), planner.forArea(Quiz10Area.HISTORY))) {
            val completed = assertIs<Outcome.Success<CompletedCoverageQuestions>>(
                CoverageQuestionCompleter().complete(plan, route(plan), CoverageQuestionReview.of(validRows()))
            ).value
            assertEquals((1..10).toList(), completed.positions.map { it.position })
            assertEquals(plan.positions.map { it.area }, completed.positions.map { it.area })
            assertEquals(plan.positions.map { it.difficulty }, completed.positions.map { it.difficulty })
            assertEquals(0, completed.replacedQuestions)
            assertEquals(0, completed.replacementAttempts)
            assertFailsWith<UnsupportedOperationException> {
                (completed.positions as MutableList<CompletedCoverageQuestion>).clear()
            }
        }
    }

    @Test
    fun incorporatesReplacementsFromReviewAndAuditsTheirOriginalIssues() {
        val plan = planner.random()
        val rows = validRows().toMutableList<CoverageQuestionReviewPosition>()
        for (index in listOf(1, 7)) rows[index] = CoverageQuestionReviewPosition.Replaced(
            "Invalid $index", "Replacement $index", "New answer $index", listOf("X", "Y", "Z")
        )
        val audits = mutableListOf<String>()
        val completer = CoverageQuestionCompleter(object : CoverageQuestionAuditListener {
            override fun onInitialReviewRejected(position: Int, issue: String) { audits += "$position:$issue" }
            override fun onReplacementOutcome(position: Int, attempt: Int, accepted: Boolean, issue: String?) {
                audits += "$position:$attempt:$accepted"
            }
        })
        val result = assertIs<Outcome.Success<CompletedCoverageQuestions>>(
            completer.complete(plan, route(plan), CoverageQuestionReview.of(rows))
        ).value
        assertEquals("Replacement 1", result.positions[1].question)
        assertEquals("New answer 7", result.positions[7].answer)
        assertEquals("Question 6", result.positions[6].question)
        assertEquals(2, result.invalidatedPositions)
        assertEquals(2, result.replacedQuestions)
        assertEquals(0, result.replacementAttempts)
        assertEquals(listOf("2:Invalid 1", "2:1:true", "8:Invalid 7", "8:1:true"), audits)
    }

    @Test
    fun rejectsUnresolvedPositionWithoutFurtherGeneration() {
        val plan = planner.random()
        val rows = validRows().toMutableList<CoverageQuestionReviewPosition>()
        rows[8] = CoverageQuestionReviewPosition.Invalid("Incomplete replacement")
        val failure = assertIs<Outcome.Failure<CoverageQuestionCompletionError>>(
            CoverageQuestionCompleter().complete(plan, route(plan), CoverageQuestionReview.of(rows))
        )
        assertEquals(CoverageQuestionCompletionError.ExhaustedReplacementAttempts(listOf(9)), failure.error)
    }

    @Test
    fun rejectsRouteThatDoesNotMatchPlan() {
        val plan = planner.random()
        val wrongRoute = route(planner.forArea(Quiz10Area.HISTORY))
        val failure = assertIs<Outcome.Failure<CoverageQuestionCompletionError>>(
            CoverageQuestionCompleter().complete(plan, wrongRoute, CoverageQuestionReview.of(validRows()))
        )
        assertIs<CoverageQuestionCompletionError.InputMismatch>(failure.error)
    }
}
