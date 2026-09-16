package dev.magullodev.quiz10.systems.quiz10.navigation

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class Quiz10NavigationTest {
    @Test
    fun normalizesTopic() {
        val menu = Quiz10NavigationMenu.forTopic("  Historia  ")

        assertEquals("🔂 Otro Quiz10 de Historia", menu.options.first().label)
    }

    @Test
    fun rejectsBlankTopic() {
        for (blank in listOf("", " ", "\t\n")) {
            assertFailsWith<IllegalArgumentException> {
                Quiz10NavigationMenu.forTopic(blank)
            }
        }
    }

    @Test
    fun exposesExactlySixOptions() {
        val menu = Quiz10NavigationMenu.forTopic("Historia")

        assertEquals(6, menu.options.size)
    }

    @Test
    fun keepsStableOptionOrder() {
        val menu = Quiz10NavigationMenu.forTopic("Historia")

        assertEquals(
            listOf(
                "🔂 Otro Quiz10 de Historia",
                "🎲 Un Quiz10 al azar",
                "🕵🏻‍♂️ Elegir otro tema",
                "❌ Repasar respuestas fallidas",
                "📚 Ver fuentes y enlaces de interés",
                "🖼️ Crear una ImageQuiz con DALL·E",
            ),
            menu.options.map { it.label },
        )
    }

    @Test
    fun usesStableIdentifiers() {
        val menu = Quiz10NavigationMenu.forTopic("Historia")

        assertEquals(
            listOf(
                "another_quiz_same_topic",
                "random_quiz",
                "choose_another_topic",
                "review_wrong_answers",
                "view_sources",
                "create_image_quiz",
            ),
            menu.options.map { it.option.id },
        )
    }

    @Test
    fun interpolatesTopicOnlyInFirstOption() {
        val menu = Quiz10NavigationMenu.forTopic("Historia")

        assertEquals("🔂 Otro Quiz10 de Historia", menu.options[0].label)
        assertEquals("🎲 Un Quiz10 al azar", menu.options[1].label)
        assertEquals("🕵🏻‍♂️ Elegir otro tema", menu.options[2].label)
        assertEquals("❌ Repasar respuestas fallidas", menu.options[3].label)
        assertEquals("📚 Ver fuentes y enlaces de interés", menu.options[4].label)
        assertEquals("🖼️ Crear una ImageQuiz con DALL·E", menu.options[5].label)
    }
}
