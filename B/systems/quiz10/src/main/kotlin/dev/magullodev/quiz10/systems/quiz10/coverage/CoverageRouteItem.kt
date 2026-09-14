package dev.magullodev.quiz10.systems.quiz10.coverage

data class CoverageRouteItem(
    val difficulty: CoverageDifficulty,
    val area: String,
    val group: String,
    val referent: String,
    val knowledge: String,
    val answer: String,
)
