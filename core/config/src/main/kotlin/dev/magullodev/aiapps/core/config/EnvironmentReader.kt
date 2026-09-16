package dev.magullodev.aiapps.core.config

fun interface EnvironmentReader {
    fun get(name: String): String?
}

object SystemEnvironmentReader : EnvironmentReader {
    override fun get(name: String): String? = System.getenv(name)
}
