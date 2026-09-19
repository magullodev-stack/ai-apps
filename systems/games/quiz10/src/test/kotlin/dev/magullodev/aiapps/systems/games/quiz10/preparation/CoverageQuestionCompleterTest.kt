package dev.magullodev.aiapps.systems.games.quiz10.preparation

import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRouteItem
import dev.magullodev.aiapps.systems.games.quiz10.coverage.Quiz10Area
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlan
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlanner
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.AcceptedCoverageQuestion
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.CoverageQuestionReview
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.CoverageQuestionReviewPosition
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.ReplacementQuestionBatch
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.ReplacementQuestionGenerationError
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.ReplacementQuestionOutcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.ReplacementQuestionPosition
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.ReplacementQuestionResult
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

class CoverageQuestionCompleterTest {
    private data class AuditEvent(
        val kind: String,
        val position: Int,
        val attempt: Int? = null,
        val accepted: Boolean? = null,
        val issue: String? = null,
    )

    private fun planRandom(): StandardCoveragePlan = StandardCoveragePlanner(Random(13)).random()

    private fun planSingleArea(): StandardCoveragePlan = StandardCoveragePlanner(Random(13)).forArea(Quiz10Area.HISTORY)

    private fun routeFromPlan(plan: StandardCoveragePlan): CoverageRoute = CoverageRoute.of(
        plan.positions.map { position ->
            CoverageRouteItem(
                difficulty = position.difficulty,
                area = position.area.label,
                group = "Group ${position.position}",
                referent = "Referent ${position.position}",
                knowledge = "Knowledge ${position.position}",
                answer = "Answer ${position.position}",
            )
        },
    )

    private fun validReview(plan: StandardCoveragePlan): CoverageQuestionReview = CoverageQuestionReview.of(
        plan.positions.map { position ->
            CoverageQuestionReviewPosition.Valid(
                question = "Question ${position.position}",
                answer = "Answer ${position.position}",
                distractors = listOf("D${position.position}A", "D${position.position}B", "D${position.position}C"),
            )
        },
    )

    private fun mixedReview(plan: StandardCoveragePlan, invalidPositions: Set<Int>): CoverageQuestionReview = CoverageQuestionReview.of(
        plan.positions.map { position ->
            if (position.position in invalidPositions) {
                CoverageQuestionReviewPosition.Invalid("Invalid ${position.position}")
            } else {
                CoverageQuestionReviewPosition.Valid(
                    question = "Question ${position.position}",
                    answer = "Answer ${position.position}",
                    distractors = listOf("D${position.position}A", "D${position.position}B", "D${position.position}C"),
                )
            }
        },
    )

    @Test
    fun tenValidRowsDoNotCallReplacementGenerator() {
        val plan = planRandom()
        val route = routeFromPlan(plan)
        val review = validReview(plan)
        var calls = 0
        val completer = CoverageQuestionCompleter { _, _ ->
            calls += 1
            Outcome.Failure(ReplacementQuestionGenerationError.InvalidStructuredResponse)
        }

        val result = completer.complete(plan, route, review)

        val completed = assertIs<Outcome.Success<CompletedCoverageQuestions>>(result).value
        assertEquals(0, calls)
        assertEquals((1..10).toList(), completed.positions.map { it.position })
    }

    @Test
    fun tenValidRowsEmitNoAuditEvents() {
        val plan = planRandom()
        val route = routeFromPlan(plan)
        val review = validReview(plan)
        val audit = mutableListOf<AuditEvent>()

        val completer = CoverageQuestionCompleter(
            generateReplacements = { _, _ ->
                error("Must not call replacements")
            },
            auditListener = object : CoverageQuestionAuditListener {
                override fun onInitialReviewRejected(position: Int, issue: String) {
                    audit += AuditEvent(kind = "review", position = position, issue = issue)
                }

                override fun onReplacementOutcome(position: Int, attempt: Int, accepted: Boolean, issue: String?) {
                    audit += AuditEvent(kind = "replacement", position = position, attempt = attempt, accepted = accepted, issue = issue)
                }
            },
        )

        val result = completer.complete(plan, route, review)
        assertIs<Outcome.Success<CompletedCoverageQuestions>>(result)
        assertTrue(audit.isEmpty())
    }

    @Test
    fun oneInvalidRowTriggersSingleReplacementWithOriginalAreaAndDifficulty() {
        val plan = planRandom()
        val route = routeFromPlan(plan)
        val review = mixedReview(plan, setOf(4))
        val calls = mutableListOf<List<ReplacementQuestionPosition>>()

        val completer = CoverageQuestionCompleter { pending, _ ->
            calls += pending
            Outcome.Success(
                ReplacementQuestionBatch.of(
                    listOf(
                        ReplacementQuestionResult(
                            position = 4,
                            outcome = ReplacementQuestionOutcome.Valid(
                                question = "Replacement Q4",
                                answer = "Replacement A4",
                                distractors = listOf("R4A", "R4B", "R4C"),
                            ),
                        ),
                    ),
                ),
            )
        }

        val completed = assertIs<Outcome.Success<CompletedCoverageQuestions>>(completer.complete(plan, route, review)).value

        assertEquals(1, calls.size)
        assertEquals(listOf(4), calls.single().map { it.position })
        val requested = calls.single().single()
        assertEquals(plan.positions[3].area.label, requested.areaLabel)
        assertEquals(plan.positions[3].difficulty, requested.difficulty)
        assertEquals("Replacement Q4", completed.positions[3].question)
    }

    @Test
    fun severalInvalidRowsAreRequestedInSingleInitialBatchOnlyForThosePositions() {
        val plan = planRandom()
        val route = routeFromPlan(plan)
        val review = mixedReview(plan, setOf(2, 7, 10))
        val calls = mutableListOf<List<Int>>()

        val completer = CoverageQuestionCompleter { pending, _ ->
            calls += pending.map { it.position }
            Outcome.Success(
                ReplacementQuestionBatch.of(
                    pending.map {
                        ReplacementQuestionResult(
                            position = it.position,
                            outcome = ReplacementQuestionOutcome.Valid(
                                question = "Replacement Q${it.position}",
                                answer = "Replacement A${it.position}",
                                distractors = listOf("X${it.position}A", "X${it.position}B", "X${it.position}C"),
                            ),
                        )
                    },
                ),
            )
        }

        assertIs<Outcome.Success<CompletedCoverageQuestions>>(completer.complete(plan, route, review))
        assertEquals(listOf(listOf(2, 7, 10)), calls)
    }

    @Test
    fun singleAreaPlanKeepsSameAreaForAllSubstitutions() {
        val plan = planSingleArea()
        val route = routeFromPlan(plan)
        val review = mixedReview(plan, setOf(1, 2, 3))

        val completer = CoverageQuestionCompleter { pending, _ ->
            pending.forEach { assertEquals("Historia", it.areaLabel) }
            Outcome.Success(
                ReplacementQuestionBatch.of(
                    pending.map {
                        ReplacementQuestionResult(
                            position = it.position,
                            outcome = ReplacementQuestionOutcome.Valid(
                                question = "Replacement Q${it.position}",
                                answer = "Replacement A${it.position}",
                                distractors = listOf("A", "B", "C"),
                            ),
                        )
                    },
                ),
            )
        }

        val completed = assertIs<Outcome.Success<CompletedCoverageQuestions>>(completer.complete(plan, route, review)).value
        assertTrue(completed.positions.all { it.area == Quiz10Area.HISTORY })
    }

    @Test
    fun preservesOriginalQuestionsAndOrderAfterReplacement() {
        val plan = planRandom()
        val route = routeFromPlan(plan)
        val review = mixedReview(plan, setOf(5, 6))

        val completer = CoverageQuestionCompleter { pending, _ ->
            Outcome.Success(
                ReplacementQuestionBatch.of(
                    pending.map {
                        ReplacementQuestionResult(
                            position = it.position,
                            outcome = ReplacementQuestionOutcome.Valid(
                                question = "Replacement Q${it.position}",
                                answer = "Replacement A${it.position}",
                                distractors = listOf("DA", "DB", "DC"),
                            ),
                        )
                    },
                ),
            )
        }

        val completed = assertIs<Outcome.Success<CompletedCoverageQuestions>>(completer.complete(plan, route, review)).value
        assertEquals((1..10).toList(), completed.positions.map { it.position })
        assertEquals("Question 4", completed.positions[3].question)
        assertEquals("Replacement Q5", completed.positions[4].question)
        assertEquals("Replacement Q6", completed.positions[5].question)
        assertEquals("Question 7", completed.positions[6].question)
    }

    @Test
    fun secondAttemptRequestsOnlyStillPendingAndIncludesAcceptedFromPreviousAttempts() {
        val plan = planRandom()
        val route = routeFromPlan(plan)
        val review = mixedReview(plan, setOf(2, 8))
        var call = 0
        val pendingByCall = mutableListOf<List<Int>>()
        val acceptedByCall = mutableListOf<List<Int>>()

        val completer = CoverageQuestionCompleter { pending, accepted ->
            call += 1
            pendingByCall += pending.map { it.position }
            acceptedByCall += accepted.map { it.position }

            when (call) {
                1 -> Outcome.Success(
                    ReplacementQuestionBatch.of(
                        listOf(
                            ReplacementQuestionResult(
                                position = 2,
                                outcome = ReplacementQuestionOutcome.Valid(
                                    question = "Replacement Q2",
                                    answer = "Replacement A2",
                                    distractors = listOf("A2", "B2", "C2"),
                                ),
                            ),
                            ReplacementQuestionResult(
                                position = 8,
                                outcome = ReplacementQuestionOutcome.Invalid("Duplicated question"),
                            ),
                        ),
                    ),
                )
                else -> Outcome.Success(
                    ReplacementQuestionBatch.of(
                        listOf(
                            ReplacementQuestionResult(
                                position = 8,
                                outcome = ReplacementQuestionOutcome.Valid(
                                    question = "Replacement Q8",
                                    answer = "Replacement A8",
                                    distractors = listOf("A8", "B8", "C8"),
                                ),
                            ),
                        ),
                    ),
                )
            }
        }

        val completed = assertIs<Outcome.Success<CompletedCoverageQuestions>>(completer.complete(plan, route, review)).value
        assertEquals(listOf(listOf(2, 8), listOf(8)), pendingByCall)
        assertTrue(2 in acceptedByCall[1])
        assertEquals("Replacement Q2", completed.positions[1].question)
        assertEquals("Replacement Q8", completed.positions[7].question)
    }

    @Test
    fun auditCapturesReviewRejectionAndReplacementOutcomesAcrossAttempts() {
        val plan = planRandom()
        val route = routeFromPlan(plan)
        val review = mixedReview(plan, setOf(6))
        val audit = mutableListOf<AuditEvent>()
        var call = 0

        val completer = CoverageQuestionCompleter(
            generateReplacements = { pending, _ ->
                call += 1
                val position = pending.single().position
                when (call) {
                    1 -> Outcome.Success(
                        ReplacementQuestionBatch.of(
                            listOf(
                                ReplacementQuestionResult(
                                    position = position,
                                    outcome = ReplacementQuestionOutcome.Invalid("Duplicada"),
                                ),
                            ),
                        ),
                    )
                    2 -> Outcome.Success(
                        ReplacementQuestionBatch.of(
                            listOf(
                                ReplacementQuestionResult(
                                    position = position,
                                    outcome = ReplacementQuestionOutcome.Invalid("Fuera de tema"),
                                ),
                            ),
                        ),
                    )
                    else -> Outcome.Success(
                        ReplacementQuestionBatch.of(
                            listOf(
                                ReplacementQuestionResult(
                                    position = position,
                                    outcome = ReplacementQuestionOutcome.Valid(
                                        question = "Replacement Q6",
                                        answer = "Replacement A6",
                                        distractors = listOf("A", "B", "C"),
                                    ),
                                ),
                            ),
                        ),
                    )
                }
            },
            auditListener = object : CoverageQuestionAuditListener {
                override fun onInitialReviewRejected(position: Int, issue: String) {
                    audit += AuditEvent(kind = "review", position = position, issue = issue)
                }

                override fun onReplacementOutcome(position: Int, attempt: Int, accepted: Boolean, issue: String?) {
                    audit += AuditEvent(kind = "replacement", position = position, attempt = attempt, accepted = accepted, issue = issue)
                }
            },
        )

        val completed = assertIs<Outcome.Success<CompletedCoverageQuestions>>(completer.complete(plan, route, review)).value

        assertEquals("Replacement Q6", completed.positions[5].question)
        assertEquals(
            listOf(
                AuditEvent(kind = "review", position = 6, issue = "Invalid 6"),
                AuditEvent(kind = "replacement", position = 6, attempt = 1, accepted = false, issue = "Duplicada"),
                AuditEvent(kind = "replacement", position = 6, attempt = 2, accepted = false, issue = "Fuera de tema"),
                AuditEvent(kind = "replacement", position = 6, attempt = 3, accepted = true, issue = null),
            ),
            audit,
        )
    }

    @Test
    fun returnsTypedErrorAfterThreeAttemptsIfPendingRemain() {
        val plan = planRandom()
        val route = routeFromPlan(plan)
        val review = mixedReview(plan, setOf(9))
        var calls = 0

        val completer = CoverageQuestionCompleter { pending, _ ->
            calls += 1
            Outcome.Success(
                ReplacementQuestionBatch.of(
                    pending.map {
                        ReplacementQuestionResult(
                            position = it.position,
                            outcome = ReplacementQuestionOutcome.Invalid("Still invalid"),
                        )
                    },
                ),
            )
        }

        val result = completer.complete(plan, route, review)

        val error = assertIs<Outcome.Failure<CoverageQuestionCompletionError>>(result).error
        assertEquals(
            CoverageQuestionCompletionError.ExhaustedReplacementAttempts(listOf(9)),
            error,
        )
        assertEquals(3, calls)
    }

    @Test
    fun technicalGeneratorFailureIsPropagatedAsTypedError() {
        val plan = planRandom()
        val route = routeFromPlan(plan)
        val review = mixedReview(plan, setOf(1))

        val completer = CoverageQuestionCompleter { _, _ ->
            Outcome.Failure(ReplacementQuestionGenerationError.GenerationFailed(AiError.TransportFailure))
        }

        val result = completer.complete(plan, route, review)
        assertEquals(
            CoverageQuestionCompletionError.ReplacementGenerationFailed(
                ReplacementQuestionGenerationError.GenerationFailed(AiError.TransportFailure),
            ),
            assertIs<Outcome.Failure<CoverageQuestionCompletionError>>(result).error,
        )
    }

    @Test
    fun resultIsImmutable() {
        val plan = planRandom()
        val route = routeFromPlan(plan)
        val review = validReview(plan)
        val completer = CoverageQuestionCompleter { _, _ ->
            error("Must not call replacements")
        }

        val completed = assertIs<Outcome.Success<CompletedCoverageQuestions>>(completer.complete(plan, route, review)).value

        @Suppress("UNCHECKED_CAST")
        val mutable = completed.positions as MutableList<CompletedCoverageQuestion>
        kotlin.test.assertFailsWith<UnsupportedOperationException> { mutable.clear() }
    }
}
