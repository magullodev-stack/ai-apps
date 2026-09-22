package dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación

import java.util.Collections

class CoverageRoute private constructor(
    val items: List<CoverageRouteItem>,
) {
    val size: Int
        get() = items.size

    companion object {
        fun of(items: List<CoverageRouteItem>): CoverageRoute {
            val snapshot = items.toList()
            require(snapshot.isNotEmpty()) { "Coverage route must not be empty" }
            require(snapshot.zipWithNext().all { (previous, next) -> previous.difficulty <= next.difficulty }) {
                "Coverage difficulty must not decrease"
            }
            val referents = snapshot.map { it.referent.trim().lowercase() }
            require(referents.toSet().size == snapshot.size) { "Coverage referents must be unique" }

            return CoverageRoute(Collections.unmodifiableList(snapshot))
        }
    }
}
