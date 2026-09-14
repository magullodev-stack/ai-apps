package dev.magullodev.quiz10.core.config

sealed interface ConfigError {
    data class MissingOrEmpty(val variable: String) : ConfigError
    data class InvalidValue(val variable: String, val value: String) : ConfigError
}
