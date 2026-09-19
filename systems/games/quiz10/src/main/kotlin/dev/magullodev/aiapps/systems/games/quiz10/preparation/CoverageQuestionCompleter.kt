package dev.magullodev.aiapps.systems.games.quiz10.preparation

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.coverage.Quiz10Area
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlan
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePosition
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.AcceptedCoverageQuestion
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.CoverageQuestionReview
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.CoverageQuestionReviewPosition
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.ReplacementQuestionBatch
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.ReplacementQuestionGenerationError
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.ReplacementQuestionOutcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.ReplacementQuestionPosition
import java.util.Collections

class CoverageQuestionCompleter(
    private val auditListener: CoverageQuestionAuditListener = CoverageQuestionAuditListener.NOOP,
    private val generateReplacements: (List<ReplacementQuestionPosition>, List<AcceptedCoverageQuestion>) -> Outcome<ReplacementQuestionBatch, ReplacementQuestionGenerationError>,
) {
    fun complete(
        plan: StandardCoveragePlan,
        route: CoverageRoute,
        review: CoverageQuestionReview,
    ): Outcome<CompletedCoverageQuestions, CoverageQuestionCompletionError> {
        val inputValidation = validateInputs(plan, route, review)
        if (inputValidation != null) {
            return Outcome.Failure(inputValidation)
        }

        val acceptedByPosition = mutableMapOf<Int, CompletedCoverageQuestion>()
        val pendingPositions = mutableSetOf<Int>()

        plan.positions.forEachIndexed { index, position ->
            when (val reviewed = review.positions[index]) {
                is CoverageQuestionReviewPosition.Valid -> {
                    acceptedByPosition[position.position] = CompletedCoverageQuestion(
                        position = position.position,
                        area = position.area,
                        difficulty = position.difficulty,
                        question = reviewed.question,
                        answer = reviewed.answer,
                        distractors = reviewed.distractors,
                    )
                }
                is CoverageQuestionReviewPosition.Invalid -> {
                    pendingPositions += position.position
                    auditListener.onInitialReviewRejected(position.position, reviewed.issue)
                }
            }
        }

        val initialInvalidatedPositions = pendingPositions.size
        var replacementAttemptsUsed = 0

        if (pendingPositions.isEmpty()) {
            return Outcome.Success(
                CompletedCoverageQuestions.of(
                    positions = plan.positions.map { checkNotNull(acceptedByPosition[it.position]) },
                    invalidatedPositions = 0,
                    replacementAttempts = 0,
                ),
            )
        }

        repeat(maxAttempts) {
            if (pendingPositions.isEmpty()) return@repeat
            replacementAttemptsUsed += 1

            val requestPositions = plan.positions
                .filter { it.position in pendingPositions }
                .map(::toReplacementPosition)

            val acceptedContext = acceptedByPosition.values
                .sortedBy { it.position }
                .map {
                    AcceptedCoverageQuestion(
                        position = it.position,
                        question = it.question,
                        answer = it.answer,
                    )
                }

            val generation = when (val result = generateReplacements(requestPositions, acceptedContext)) {
                is Outcome.Success -> result.value
                is Outcome.Failure -> {
                    return Outcome.Failure(CoverageQuestionCompletionError.ReplacementGenerationFailed(result.error))
                }
            }

            generation.results.forEach { generated ->
                val position = generated.position
                if (position !in pendingPositions) return@forEach

                when (val outcome = generated.outcome) {
                    is ReplacementQuestionOutcome.Valid -> {
                        auditListener.onReplacementOutcome(position, replacementAttemptsUsed, accepted = true, issue = null)
                        val planPosition = checkNotNull(plan.positions.find { it.position == position })
                        acceptedByPosition[position] = CompletedCoverageQuestion(
                            position = position,
                            area = planPosition.area,
                            difficulty = planPosition.difficulty,
                            question = outcome.question,
                            answer = outcome.answer,
                            distractors = outcome.distractors,
                        )
                        pendingPositions -= position
                    }
                    is ReplacementQuestionOutcome.Invalid -> {
                        auditListener.onReplacementOutcome(
                            position = position,
                            attempt = replacementAttemptsUsed,
                            accepted = false,
                            issue = outcome.issue,
                        )
                    }
                }
            }
        }

        if (pendingPositions.isNotEmpty()) {
            return Outcome.Failure(CoverageQuestionCompletionError.ExhaustedReplacementAttempts(pendingPositions.toList().sorted()))
        }

        return Outcome.Success(
            CompletedCoverageQuestions.of(
                positions = plan.positions.map { checkNotNull(acceptedByPosition[it.position]) },
                invalidatedPositions = initialInvalidatedPositions,
                replacementAttempts = replacementAttemptsUsed,
            ),
        )
    }

    private fun validateInputs(
        plan: StandardCoveragePlan,
        route: CoverageRoute,
        review: CoverageQuestionReview,
    ): CoverageQuestionCompletionError? {
        if (plan.size != 10 || route.size != 10 || review.positions.size != 10) {
            return CoverageQuestionCompletionError.InputMismatch("Plan, route and review must each contain exactly 10 positions")
        }

        plan.positions.forEachIndexed { index, position ->
            val routeItem = route.items[index]
            if (routeItem.area != position.area.label || routeItem.difficulty != position.difficulty) {
                return CoverageQuestionCompletionError.InputMismatch(
                    "Route does not match plan at position ${position.position}",
                )
            }
        }

        return null
    }

    private fun toReplacementPosition(position: StandardCoveragePosition): ReplacementQuestionPosition =
        ReplacementQuestionPosition(
            position = position.position,
            areaLabel = position.area.label,
            difficulty = position.difficulty,
        )

    private companion object {
        const val maxAttempts = 3
    }
}

interface CoverageQuestionAuditListener {
    fun onInitialReviewRejected(position: Int, issue: String)

    fun onReplacementOutcome(position: Int, attempt: Int, accepted: Boolean, issue: String?)

    companion object {
        val NOOP: CoverageQuestionAuditListener = object : CoverageQuestionAuditListener {
            override fun onInitialReviewRejected(position: Int, issue: String) = Unit

            override fun onReplacementOutcome(position: Int, attempt: Int, accepted: Boolean, issue: String?) = Unit
        }
    }
}

class CompletedCoverageQuestions private constructor(
    val positions: List<CompletedCoverageQuestion>,
    val invalidatedPositions: Int,
    val replacementAttempts: Int,
) {
    val replacedQuestions: Int
        get() = invalidatedPositions

    companion object {
        fun of(
            positions: List<CompletedCoverageQuestion>,
            invalidatedPositions: Int = 0,
            replacementAttempts: Int = 0,
        ): CompletedCoverageQuestions {
            val snapshot = positions.toList()
            require(snapshot.size == 10) { "Completed coverage questions must contain exactly 10 positions" }
            require(snapshot.map { it.position } == (1..10).toList()) {
                "Completed coverage questions must remain ordered by original position"
            }
            require(invalidatedPositions >= 0) { "Invalidated positions must be >= 0" }
            require(replacementAttempts >= 0) { "Replacement attempts must be >= 0" }
            return CompletedCoverageQuestions(
                positions = Collections.unmodifiableList(snapshot),
                invalidatedPositions = invalidatedPositions,
                replacementAttempts = replacementAttempts,
            )
        }
    }
}

data class CompletedCoverageQuestion(
    val position: Int,
    val area: Quiz10Area,
    val difficulty: CoverageDifficulty,
    val question: String,
    val answer: String,
    val distractors: List<String>,
) {
    init {
        require(position in 1..10) { "Position must be between 1 and 10" }
        require(question.isNotBlank()) { "Question must not be blank" }
        require(answer.isNotBlank()) { "Answer must not be blank" }
        require(distractors.size == 3) { "Exactly three distractors are required" }
        require(distractors.all { it.isNotBlank() }) { "Distractors must not be blank" }
    }
}

sealed interface CoverageQuestionCompletionError {
    data class InputMismatch(val detail: String) : CoverageQuestionCompletionError
    data class ReplacementGenerationFailed(val cause: ReplacementQuestionGenerationError) : CoverageQuestionCompletionError
    data class ExhaustedReplacementAttempts(val pendingPositions: List<Int>) : CoverageQuestionCompletionError
}
