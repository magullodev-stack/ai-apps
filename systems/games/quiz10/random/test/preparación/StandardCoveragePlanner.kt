package dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación

import kotlin.random.Random

class StandardCoveragePlanner(
    private val random: Random = Random.Default,
) {
    fun random(): StandardCoveragePlan {
        val selectedAreas = Quiz10Area.catalog.shuffled(random).take(CoverageDifficultyByPosition.standardPositionCount)
        return buildPlan { index -> selectedAreas[index] }
    }

    fun forArea(area: Quiz10Area): StandardCoveragePlan = buildPlan { area }

    private fun buildPlan(areaAtIndex: (Int) -> Quiz10Area): StandardCoveragePlan = StandardCoveragePlan.of(
        List(CoverageDifficultyByPosition.standardPositionCount) { index ->
            val position = index + 1
            StandardCoveragePosition(
                position = position,
                area = areaAtIndex(index),
                difficulty = CoverageDifficultyByPosition.forPosition(position),
            )
        },
    )
}