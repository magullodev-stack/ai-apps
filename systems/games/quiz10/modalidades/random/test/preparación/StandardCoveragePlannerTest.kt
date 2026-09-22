package dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación

import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class StandardCoveragePlannerTest {
    @Test
    fun randomPlanContainsTenValidDifferentAreas() {
        val plan = StandardCoveragePlanner(Random(1234)).random()

        assertEquals(10, plan.size)
        assertTrue(plan.positions.all { it.area in Quiz10Area.catalog })
        assertEquals(10, plan.positions.map { it.area }.toSet().size)
    }

    @Test
    fun fixedAreaPlanContainsTheRequestedAreaInAllPositions() {
        val area = Quiz10Area.PHYSICS
        val plan = StandardCoveragePlanner(Random(1234)).forArea(area)

        assertEquals(10, plan.size)
        assertTrue(plan.positions.all { it.area == area })
    }

    @Test
    fun bothModesUseCanonicalDifficultyDistributionAndPreservePositionOrder() {
        val expectedDifficulties = List(4) { CoverageDifficulty.EASY } +
            List(3) { CoverageDifficulty.MODERATE } +
            List(2) { CoverageDifficulty.HARD } +
            CoverageDifficulty.VERY_HARD

        val randomPlan = StandardCoveragePlanner(Random(10)).random()
        val fixedPlan = StandardCoveragePlanner(Random(10)).forArea(Quiz10Area.HISTORY)

        assertEquals((1..10).toList(), randomPlan.positions.map { it.position })
        assertEquals((1..10).toList(), fixedPlan.positions.map { it.position })
        assertEquals(expectedDifficulties, randomPlan.positions.map { it.difficulty })
        assertEquals(expectedDifficulties, fixedPlan.positions.map { it.difficulty })
    }

    @Test
    fun randomSelectionIsReproducibleWithControlledRandomSource() {
        val first = StandardCoveragePlanner(Random(42)).random()
        val second = StandardCoveragePlanner(Random(42)).random()
        val third = StandardCoveragePlanner(Random(43)).random()

        assertEquals(first.positions, second.positions)
        assertTrue(first.positions != third.positions)
    }
}