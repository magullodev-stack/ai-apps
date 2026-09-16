package dev.magullodev.quiz10.systems.quiz10.coverage

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class CoverageRouteTest {
    private fun item(referent: String, difficulty: CoverageDifficulty = CoverageDifficulty.EASY) =
        CoverageRouteItem(
            difficulty = difficulty,
            area = "History",
            group = "Ancient Rome",
            referent = referent,
            knowledge = "Founding year",
            answer = "753 BC",
        )

    @Test
    fun acceptsCanonicalTenItemDifficultySequence() {
        val difficulties = List(4) { CoverageDifficulty.EASY } +
            List(3) { CoverageDifficulty.MODERATE } +
            List(2) { CoverageDifficulty.HARD } +
            CoverageDifficulty.VERY_HARD
        val items = difficulties.mapIndexed { index, difficulty -> item("Referent $index", difficulty) }

        val route = CoverageRoute.of(items)

        assertEquals(items, route.items)
        assertEquals(10, route.size)
    }

    @Test
    fun acceptsValidRoutesOfOtherLengths() {
        for (length in listOf(1, 3, 12)) {
            val items = List(length) { item("Referent $it") }

            val route = CoverageRoute.of(items)

            assertEquals(items, route.items)
            assertEquals(length, route.size)
        }
    }

    @Test
    fun preservesReceivedOrder() {
        val items = listOf(item("Zeta"), item("Alpha"), item("Delta", CoverageDifficulty.HARD))

        assertEquals(items, CoverageRoute.of(items).items)
    }

    @Test
    fun sizeReflectsActualItemCount() {
        val route = CoverageRoute.of(listOf(item("Rome"), item("Athens")))

        assertEquals(2, route.size)
    }

    @Test
    fun rejectsEmptyRoute() {
        assertFailsWith<IllegalArgumentException> { CoverageRoute.of(emptyList()) }
    }

    @Test
    fun rejectsEveryDifficultyRegression() {
        for (previous in CoverageDifficulty.entries) {
            for (next in CoverageDifficulty.entries.filter { it < previous }) {
                assertFailsWith<IllegalArgumentException> {
                    CoverageRoute.of(listOf(item("Rome", previous), item("Athens", next)))
                }
            }
        }
    }

    @Test
    fun rejectsRepeatedReferentAcrossTheRoute() {
        assertFailsWith<IllegalArgumentException> {
            CoverageRoute.of(listOf(item("Rome"), item("Athens"), item("Rome", CoverageDifficulty.HARD)))
        }
    }

    @Test
    fun rejectsReferentsDifferingOnlyInCaseOrOuterWhitespace() {
        for (duplicate in listOf("ROME", "rome", " Rome ", "\t rOmE \n")) {
            assertFailsWith<IllegalArgumentException> {
                CoverageRoute.of(listOf(item("Rome"), item(duplicate)))
            }
        }
    }

    @Test
    fun allowsRepeatedAreaAndGroup() {
        val items = listOf(item("Rome"), item("Athens"))

        val route = CoverageRoute.of(items)

        assertEquals(items, route.items)
    }

    @Test
    fun laterChangesToOriginalMutableListDoNotAffectRoute() {
        val items = mutableListOf(item("Rome"), item("Athens"))
        val expected = items.toList()
        val route = CoverageRoute.of(items)

        items[0] = item("Carthage")
        items.add(item("Alexandria"))
        items.clear()

        assertEquals(expected, route.items)
        assertEquals(2, route.size)
    }

    @Test
    fun exposedItemsCannotBeMutated() {
        val expected = listOf(item("Rome"), item("Athens"))
        val route = CoverageRoute.of(expected)

        assertFailsWith<UnsupportedOperationException> {
            (route.items as MutableList<CoverageRouteItem>).clear()
        }

        assertEquals(expected, route.items)
    }
}
