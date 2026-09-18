package dev.magullodev.quiz10.systems.quiz10.preparation

import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageRoute

class PreparedQuiz(
    val topic: String,
    val route: CoverageRoute,
) {
    init {
        require(route.size == 10) { "Prepared quiz route must have exactly 10 positions" }
    }

    companion object {
        val correctOptionSequence = listOf(0, 1, 2, 3, 0, 1, 2, 3, 0, 1)
    }
}
