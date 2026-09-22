package dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class StandardCoveragePlanTest {
    private fun canonicalPositions(area: Quiz10Area = Quiz10Area.HISTORY): List<StandardCoveragePosition> =
        List(10) { index ->
            val position = index + 1
            StandardCoveragePosition(
                position = position,
                area = area,
                difficulty = CoverageDifficultyByPosition.forPosition(position),
            )
        }

    @Test
    fun acceptsCanonicalTenPositionsPreservingOrderAndNumbering() {
        val positions = canonicalPositions()

        val plan = StandardCoveragePlan.of(positions)

        assertEquals(10, plan.size)
        assertEquals((1..10).toList(), plan.positions.map { it.position })
        assertEquals(positions, plan.positions)
    }

    @Test
    fun rejectsAnySizeDifferentFromTen() {
        assertFailsWith<IllegalArgumentException> { StandardCoveragePlan.of(emptyList()) }
        assertFailsWith<IllegalArgumentException> { StandardCoveragePlan.of(canonicalPositions().take(1)) }
        assertFailsWith<IllegalArgumentException> { StandardCoveragePlan.of(canonicalPositions().take(9)) }
        assertFailsWith<IllegalArgumentException> {
            StandardCoveragePlan.of(canonicalPositions() + canonicalPositions().first().copy(position = 11))
        }
    }

    @Test
    fun rejectsOutOfOrderOrWrongNumberedPositions() {
        val reversed = canonicalPositions().reversed()
        assertFailsWith<IllegalArgumentException> { StandardCoveragePlan.of(reversed) }

        val duplicatedNumber = canonicalPositions().toMutableList().apply {
            this[9] = this[9].copy(position = 9)
        }
        assertFailsWith<IllegalArgumentException> { StandardCoveragePlan.of(duplicatedNumber) }
    }

    @Test
    fun rejectsDifficultyDistributionDifferentFromCanonical() {
        val invalid = canonicalPositions().toMutableList().apply {
            this[0] = this[0].copy(difficulty = CoverageDifficulty.HARD)
        }
        assertFailsWith<IllegalArgumentException> { StandardCoveragePlan.of(invalid) }
    }

    @Test
    fun laterChangesToOriginalMutableListDoNotAffectPlanAndExposedPositionsCannotBeMutated() {
        val source = canonicalPositions().toMutableList()
        val expected = source.toList()
        val plan = StandardCoveragePlan.of(source)

        source.clear()

        assertEquals(expected, plan.positions)
        assertFailsWith<UnsupportedOperationException> {
            (plan.positions as MutableList<StandardCoveragePosition>).clear()
        }
    }
}