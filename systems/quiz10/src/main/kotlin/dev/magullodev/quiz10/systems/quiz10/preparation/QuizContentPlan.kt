package dev.magullodev.quiz10.systems.quiz10.preparation

import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageDifficulty
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRoute
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRouteItem
import java.util.Collections

class QuizContentPlan private constructor(
    val items: List<QuizContentPlanItem>,
) {
    init {
        require(items.size == 10) { "Quiz content plan must have exactly 10 items" }
        require(items.map { it.difficulty } == expectedDifficulties) {
            "Quiz content plan must follow Quiz10 difficulty distribution"
        }
        require(normalizedDistinctCount(items.map { it.area }) >= 2) {
            "Quiz content plan must diversify areas"
        }
        require(normalizedDistinctCount(items.map { it.group }) >= 2) {
            "Quiz content plan must diversify groups"
        }

        // Reuse canonical coverage validation for ordering and unique referents.
        toCoverageRoute()
    }

    fun toCoverageRoute(): CoverageRoute = CoverageRoute.of(
        items.map {
            CoverageRouteItem(
                difficulty = it.difficulty,
                area = it.area,
                group = it.group,
                referent = it.referent,
                knowledge = it.knowledge,
                answer = it.answer,
            )
        },
    )

    companion object {
        fun of(items: List<QuizContentPlanItem>): QuizContentPlan =
            QuizContentPlan(Collections.unmodifiableList(items.toList()))

        private val expectedDifficulties = List(4) { CoverageDifficulty.EASY } +
            List(3) { CoverageDifficulty.MODERATE } +
            List(2) { CoverageDifficulty.HARD } +
            CoverageDifficulty.VERY_HARD

        private fun normalizedDistinctCount(values: List<String>): Int =
            values.map { it.trim().lowercase() }.toSet().size
    }
}

data class QuizContentPlanItem(
    val difficulty: CoverageDifficulty,
    val area: String,
    val group: String,
    val referent: String,
    val knowledge: String,
    val answer: String,
    val question: String,
    val correctExplanation: String,
    val distractors: List<QuizContentDistractor>,
) {
    init {
        require(area.isNotBlank()) { "Plan item area must not be blank" }
        require(group.isNotBlank()) { "Plan item group must not be blank" }
        require(referent.isNotBlank()) { "Plan item referent must not be blank" }
        require(knowledge.isNotBlank()) { "Plan item knowledge must not be blank" }
        require(answer.isNotBlank()) { "Plan item answer must not be blank" }
        require(question.isNotBlank()) { "Plan item question must not be blank" }
        require(correctExplanation.isNotBlank()) { "Plan item correct explanation must not be blank" }
        require(distractors.size == 3) { "Plan item must include exactly three distractors" }

        val normalizedDistractors = distractors.map { it.text.trim().lowercase() }
        require(normalizedDistractors.toSet().size == 3) {
            "Plan item distractors must be different"
        }
        require(answer.trim().lowercase() !in normalizedDistractors) {
            "Plan item distractors must not match the correct answer"
        }
    }
}

data class QuizContentDistractor(
    val text: String,
    val explanation: String,
) {
    init {
        require(text.isNotBlank()) { "Distractor text must not be blank" }
        require(explanation.isNotBlank()) { "Distractor explanation must not be blank" }
    }
}
