package dev.magullodev.quiz10.systems.quiz10.navigation

enum class Quiz10NavigationOption(
    val id: String,
) {
    ANOTHER_QUIZ_SAME_TOPIC("another_quiz_same_topic"),
    RANDOM_QUIZ("random_quiz"),
    CHOOSE_ANOTHER_TOPIC("choose_another_topic"),
    REVIEW_WRONG_ANSWERS("review_wrong_answers"),
    VIEW_SOURCES("view_sources"),
    CREATE_IMAGE_QUIZ("create_image_quiz"),
}

class Quiz10NavigationMenu private constructor(
    private val normalizedTopic: String,
) {
    val options: List<Quiz10NavigationEntry>
        get() = listOf(
            Quiz10NavigationEntry(Quiz10NavigationOption.ANOTHER_QUIZ_SAME_TOPIC, "🔂 Otro Quiz10 de $normalizedTopic"),
            Quiz10NavigationEntry(Quiz10NavigationOption.RANDOM_QUIZ, "🎲 Un Quiz10 al azar"),
            Quiz10NavigationEntry(Quiz10NavigationOption.CHOOSE_ANOTHER_TOPIC, "🕵🏻‍♂️ Elegir otro tema"),
            Quiz10NavigationEntry(Quiz10NavigationOption.REVIEW_WRONG_ANSWERS, "❌ Repasar respuestas fallidas"),
            Quiz10NavigationEntry(Quiz10NavigationOption.VIEW_SOURCES, "📚 Ver fuentes y enlaces de interés"),
            Quiz10NavigationEntry(Quiz10NavigationOption.CREATE_IMAGE_QUIZ, "🖼️ Crear una ImageQuiz con DALL·E"),
        )

    fun select(number: Int): Quiz10NavigationOption {
        require(number in 1..options.size) { "Navigation selection must be between 1 and ${options.size}" }
        return options[number - 1].option
    }

    companion object {
        fun forTopic(topic: String): Quiz10NavigationMenu {
            val normalized = topic.trim()
            require(normalized.isNotEmpty()) { "Navigation topic must not be blank" }
            return Quiz10NavigationMenu(normalized)
        }
    }
}

data class Quiz10NavigationEntry(
    val option: Quiz10NavigationOption,
    val label: String,
)
