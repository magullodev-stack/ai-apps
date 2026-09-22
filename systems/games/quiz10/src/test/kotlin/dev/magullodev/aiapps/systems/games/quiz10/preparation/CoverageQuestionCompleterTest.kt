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
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertIs

class CoverageQuestionCompleterTest {
    private val planner = StandardCoveragePlanner(Random(13))

    private fun route(plan: StandardCoveragePlan) =
        CoverageRoute.of(
            plan.positions.map {
                CoverageRouteItem(
                    difficulty = it.difficulty,
                    area = it.area.label,
                    group = "Group ${it.position}",
                    referent = "Referent ${it.position}",
                    knowledge = "Knowledge ${it.position}",
                    answer = "Answer ${it.position}",
                )
            },
        )

    private fun validRows(): List<CoverageQuestionReviewPosition> =
        (1..10).map {
            CoverageQuestionReviewPosition.Valid(
                question = "Question $it",
                answer = "Answer $it",
                distractors = listOf("A$it", "B$it", "C$it"),
            )
        }

    @Test
    fun completesRandomAndSingleAreaPlansInOrder() {
        for (plan in listOf(
            planner.random(),
            planner.forArea(Quiz10Area.HISTORY),
        )) {
            val completed = assertIs<Outcome.Success<CompletedCoverageQuestions>>(
                CoverageQuestionCompleter().complete(
                    plan = plan,
                    route = route(plan),
                    review = CoverageQuestionReview.of(validRows()),
                ),
            ).value

            assertEquals(
                (1..10).toList(),
                completed.positions.map { it.position },
            )
            assertEquals(
                plan.positions.map { it.area },
                completed.positions.map { it.area },
            )
            assertEquals(
                plan.positions.map { it.difficulty },
                completed.positions.map { it.difficulty },
            )
            assertEquals(
                0,
                completed.replacedQuestions,
            )

            assertFailsWith<UnsupportedOperationException> {
                (completed.positions as MutableList<CompletedCoverageQuestion>).clear()
            }
        }
    }

    @Test
    fun incorporatesReplacementsAlreadyProducedByReview() {
        val plan = planner.random()
        val rows = validRows().toMutableList()

        rows[1] = CoverageQuestionReviewPosition.Replaced(
            issue = "Invalid original knowledge",
            question = "Replacement question 2",
            answer = "Replacement answer 2",
            distractors = listOf("X2", "Y2", "Z2"),
        )

        rows[7] = CoverageQuestionReviewPosition.Replaced(
            issue = "Invalid original answer",
            question = "Replacement question 8",
            answer = "Replacement answer 8",
            distractors = listOf("X8", "Y8", "Z8"),
        )

        val completed = assertIs<Outcome.Success<CompletedCoverageQuestions>>(
            CoverageQuestionCompleter().complete(
                plan = plan,
                route = route(plan),
                review = CoverageQuestionReview.of(rows),
            ),
        ).value

        assertEquals(
            "Replacement question 2",
            completed.positions[1].question,
        )
        assertEquals(
            "Replacement answer 8",
            completed.positions[7].answer,
        )
        assertEquals(
            "Question 6",
            completed.positions[5].question,
        )
        assertEquals(
            2,
            completed.replacedQuestions,
        )
    }

    @Test
    fun rejectsUnresolvedPosition() {
        val plan = planner.random()
        val rows = validRows().toMutableList()

        rows[8] = CoverageQuestionReviewPosition.Invalid(
            "TERRA 2 did not produce a valid question",
        )

        val failure = assertIs<Outcome.Failure<CoverageQuestionCompletionError>>(
            CoverageQuestionCompleter().complete(
                plan = plan,
                route = route(plan),
                review = CoverageQuestionReview.of(rows),
            ),
        )

        assertEquals(
            CoverageQuestionCompletionError.UnresolvedPositions(
                listOf(9),
            ),
            failure.error,
        )
    }

    @Test
    fun rejectsRouteThatDoesNotMatchPlan() {
        val plan = planner.random()
        val wrongRoute = route(
            planner.forArea(Quiz10Area.HISTORY),
        )

        val failure = assertIs<Outcome.Failure<CoverageQuestionCompletionError>>(
            CoverageQuestionCompleter().complete(
                plan = plan,
                route = wrongRoute,
                review = CoverageQuestionReview.of(validRows()),
            ),
        )

        assertIs<CoverageQuestionCompletionError.InputMismatch>(
            failure.error,
        )
    }
}
