package dev.magullodev.aiapps.core.contracts

sealed interface Outcome<out V, out E> {
    data class Success<out V>(val value: V) : Outcome<V, Nothing>
    data class Failure<out E>(val error: E) : Outcome<Nothing, E>
}
