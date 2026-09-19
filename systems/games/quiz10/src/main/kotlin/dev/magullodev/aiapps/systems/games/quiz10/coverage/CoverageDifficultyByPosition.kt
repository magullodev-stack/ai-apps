package dev.magullodev.aiapps.systems.games.quiz10.coverage

object CoverageDifficultyByPosition {
    const val standardPositionCount: Int = 10

    fun forPosition(position: Int): CoverageDifficulty =
        when (position) {
            in 1..4 -> CoverageDifficulty.EASY
            in 5..7 -> CoverageDifficulty.MODERATE
            in 8..9 -> CoverageDifficulty.HARD
            10 -> CoverageDifficulty.VERY_HARD
            else -> throw IllegalArgumentException("Coverage position must be between 1 and 10")
        }
}