package dev.magullodev.aiapps.systems.games.quiz10.preparation

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.coverage.Quiz10Area
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlan
import dev.magullodev.aiapps.systems.games.quiz10.random.test.processing.CoverageQuestionReview
import dev.magullodev.aiapps.systems.games.quiz10.random.test.processing.CoverageQuestionReviewPosition
import java.util.Collections

class CoverageQuestionCompleter(
    private val auditListener: CoverageQuestionAuditListener = CoverageQuestionAuditListener.NOOP,
) {
    fun complete(
        plan: StandardCoveragePlan,
        route: CoverageRoute,
        review: CoverageQuestionReview,
    ): Outcome<CompletedCoverageQuestions, CoverageQuestionCompletionError> {
        if (plan.size != 10 || route.size != 10 || review.positions.size != 10) {
            return Outcome.Failure(CoverageQuestionCompletionError.InputMismatch(
                "Plan, route and review must each contain exactly 10 positions"
            ))
        }

        val completed = mutableListOf<CompletedCoverageQuestion>()
        var replacements = 0

        plan.positions.forEachIndexed { index, position ->
            val routeItem = route.items[index]
            if (routeItem.area != position.area.label ||
                routeItem.difficulty != position.difficulty
            ) {
                return Outcome.Failure(CoverageQuestionCompletionError.InputMismatch(
                    "Route does not match plan at position ${position.position}"
                ))
            }

            val reviewed = review.positions[index]
            val question: String
            val answer: String
            val distractors: List<String>

            when (reviewed) {
                is CoverageQuestionReviewPosition.Valid -> {
                    question = reviewed.question
                    answer = reviewed.answer
                    distractors = reviewed.distractors
                }
                is CoverageQuestionReviewPosition.Replaced -> {
                    replacements++
                    auditListener.onInitialReviewRejected(position.position, reviewed.issue)
                    auditListener.onReplacementOutcome(position.position, 1, true, null)
                    question = reviewed.question
                    answer = reviewed.answer
                    distractors = reviewed.distractors
                }
                is CoverageQuestionReviewPosition.Invalid -> {
                    auditListener.onInitialReviewRejected(position.position, reviewed.issue)
                    return Outcome.Failure(
                        CoverageQuestionCompletionError.ExhaustedReplacementAttempts(
                            listOf(position.position)
                        )
                    )
                }
            }

            completed += CompletedCoverageQuestion(
                position = position.position,
                area = position.area,
                difficulty = position.difficulty,
                question = question,
                answer = answer,
                distractors = distractors,
            )
        }

        return Outcome.Success(CompletedCoverageQuestions.of(
            positions = completed,
            invalidatedPositions = replacements,
            replacementAttempts = 0,
        ))
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
    data class ExhaustedReplacementAttempts(val pendingPositions: List<Int>) : CoverageQuestionCompletionError
}
