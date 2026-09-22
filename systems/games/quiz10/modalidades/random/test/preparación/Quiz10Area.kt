package dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación

enum class Quiz10Area(
    val label: String,
) {
    MATHEMATICS("Matemáticas"),
    PHYSICS("Física"),
    CHEMISTRY("Química"),
    EARTH_AND_SPACE("Tierra y espacio"),
    BIOLOGY("Biología"),
    HEALTH("Salud"),
    COMPUTER_SCIENCE("Informática"),
    ENGINEERING("Ingeniería"),
    ARCHITECTURE("Arquitectura"),
    HISTORY("Historia"),
    LINGUISTICS("Lingüística"),
    LITERATURE("Literatura"),
    PHILOSOPHY("Filosofía"),
    LAW("Derecho"),
    ECONOMICS("Economía"),
    PSYCHOLOGY("Psicología"),
    SOCIOLOGY("Sociología"),
    POLITICAL_SCIENCE("Ciencia política"),
    ;

    companion object {
        val catalog: List<Quiz10Area> = entries

        private val byLabel = entries.associateBy { it.label }

        fun fromLabel(label: String): Quiz10Area? = byLabel[label]
    }
}