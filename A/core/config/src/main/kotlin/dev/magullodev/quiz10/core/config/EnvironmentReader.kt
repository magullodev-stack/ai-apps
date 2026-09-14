package dev.magullodev.quiz10.core.config

fun interface EnvironmentReader {
    fun get(name: String): String?
}

object SystemEnvironmentReader : EnvironmentReader {
    override fun get(name: String): String? = System.getenv(name)
}
