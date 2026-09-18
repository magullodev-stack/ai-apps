package dev.magullodev.quiz10.systems.quiz10.coverage.terra

import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageDifficulty
import java.util.Collections

/** Terra coverage proposal validated independently of the question generation flow. */
class CoverageRoute private constructor(val items: List<CoverageRouteItem>) {
    fun difficultyForRow(row: Int): CoverageDifficulty {
        require(row in 1..10) { "Coverage row must be between 1 and 10" }
        return when (row) {
            in 1..4 -> CoverageDifficulty.EASY
            in 5..7 -> CoverageDifficulty.MODERATE
            in 8..9 -> CoverageDifficulty.HARD
            else -> CoverageDifficulty.VERY_HARD
        }
    }

    companion object {
        fun of(items: List<CoverageRouteItem>): CoverageRoute {
            val snapshot = items.toList()
            require(snapshot.size == 10) { "Coverage route must have exactly 10 items" }
            val referents = snapshot.map { it.referent.trim().lowercase() }
            require(referents.toSet().size == 10) { "Coverage referents must be unique" }
            return CoverageRoute(Collections.unmodifiableList(snapshot))
        }
    }
}

data class CoverageRouteItem(
    val emoji: String,
    val area: String,
    val group: String,
    val referent: String,
    val knowledge: String,
    val answer: String,
) {
    init {
        require(listOf(emoji, area, group, referent, knowledge, answer).all { it.isNotBlank() }) {
            "Coverage fields must not be blank"
        }
    }
}
