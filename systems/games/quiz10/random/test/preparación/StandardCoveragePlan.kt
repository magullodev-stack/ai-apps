package dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación

import java.util.Collections

data class StandardCoveragePosition(
    val position: Int,
    val area: Quiz10Area,
    val difficulty: CoverageDifficulty,
) {
    init {
        require(position in 1..CoverageDifficultyByPosition.standardPositionCount) {
            "Standard coverage position must be between 1 and 10"
        }
    }
}

class StandardCoveragePlan private constructor(
    val positions: List<StandardCoveragePosition>,
) {
    val size: Int
        get() = positions.size

    companion object {
        fun of(positions: List<StandardCoveragePosition>): StandardCoveragePlan {
            val snapshot = positions.toList()
            require(snapshot.size == CoverageDifficultyByPosition.standardPositionCount) {
                "Standard coverage plan must contain exactly 10 positions"
            }
            snapshot.forEachIndexed { index, position ->
                val expectedPosition = index + 1
                require(position.position == expectedPosition) {
                    "Standard coverage plan positions must be ordered from 1 to 10"
                }
                require(position.difficulty == CoverageDifficultyByPosition.forPosition(expectedPosition)) {
                    "Standard coverage plan uses the canonical 4/3/2/1 difficulty distribution"
                }
            }
            return StandardCoveragePlan(Collections.unmodifiableList(snapshot))
        }
    }
}