package dev.magullodev.aiapps.systems.games.quiz10.coverage

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class Quiz10AreaTest {
    @Test
    fun catalogContainsExactlyTheEighteenAgreedAreasWithoutDuplicates() {
        assertEquals(18, Quiz10Area.catalog.size)
        assertEquals(18, Quiz10Area.catalog.toSet().size)
    }

    @Test
    fun catalogLabelsMatchExactlyTheAgreedSet() {
        assertEquals(
            listOf(
                "Matemáticas",
                "Física",
                "Química",
                "Tierra y espacio",
                "Biología",
                "Salud",
                "Informática",
                "Ingeniería",
                "Arquitectura",
                "Historia",
                "Lingüística",
                "Literatura",
                "Filosofía",
                "Derecho",
                "Economía",
                "Psicología",
                "Sociología",
                "Ciencia política",
            ),
            Quiz10Area.catalog.map { it.label },
        )
    }

    @Test
    fun fromLabelReturnsKnownAreaAndRejectsUnknownLabels() {
        assertEquals(Quiz10Area.HISTORY, Quiz10Area.fromLabel("Historia"))
        assertNull(Quiz10Area.fromLabel("historia"))
        assertNull(Quiz10Area.fromLabel(" Historia "))
        assertNull(Quiz10Area.fromLabel("Astrología"))
    }
}