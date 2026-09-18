package dev.magullodev.aiapps.core.config

import dev.magullodev.aiapps.core.contracts.Outcome
import java.net.URI
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs

class EnvironmentConfigTest {
    private fun reader(vararg values: Pair<String, String>): EnvironmentReader {
        val variables = mapOf(*values)
        return EnvironmentReader { name -> variables[name] }
    }

    @Test
    fun loadsValidConfiguration() {
        val result = EnvironmentConfig.load(
            reader(
                "AI_APPS_ENV" to "production",
                "AI_APPS_AI_BASE_URL" to "https://example.com/api",
                "AI_APPS_AI_API_KEY" to "example-test-key",
                "AI_APPS_AI_LUNA_MODEL" to "model-luna",
                "AI_APPS_AI_MINI_MODEL" to "model-mini",
                "AI_APPS_AI_TERRA_MODEL" to "model-terra",
            ),
        )

        val config = assertIs<Outcome.Success<EnvironmentConfig>>(result).value
        assertEquals(AppEnvironment.PRODUCTION, config.environment)
        assertEquals(URI("https://example.com/api"), config.aiBaseUrl)
        assertEquals("example-test-key", config.aiApiKey)
        assertEquals(AiModelsConfig("model-luna", "model-mini", "model-terra"), config.aiModels)
        assertFalse(config.toString().contains("example-test-key"))
    }

    @Test
    fun acceptsUppercaseHttpScheme() {
        val result = EnvironmentConfig.load(
            reader(
                "AI_APPS_ENV" to "test",
                "AI_APPS_AI_BASE_URL" to "HTTP://example.com",
                "AI_APPS_AI_API_KEY" to "example-test-key",
                "AI_APPS_AI_LUNA_MODEL" to "model-luna",
                "AI_APPS_AI_MINI_MODEL" to "model-mini",
                "AI_APPS_AI_TERRA_MODEL" to "model-terra",
            ),
        )

        assertEquals(URI("HTTP://example.com"), assertIs<Outcome.Success<EnvironmentConfig>>(result).value.aiBaseUrl)
    }

    @Test
    fun acceptsEverySupportedEnvironment() {
        val environments = mapOf(
            "development" to AppEnvironment.DEVELOPMENT,
            "test" to AppEnvironment.TEST,
            "production" to AppEnvironment.PRODUCTION,
        )

        for ((name, expected) in environments) {
            val result = EnvironmentConfig.load(
                reader(
                    "AI_APPS_ENV" to name,
                    "AI_APPS_AI_BASE_URL" to "http://localhost:8080",
                    "AI_APPS_AI_API_KEY" to "example-test-key",
                    "AI_APPS_AI_LUNA_MODEL" to "model-luna",
                    "AI_APPS_AI_MINI_MODEL" to "model-mini",
                    "AI_APPS_AI_TERRA_MODEL" to "model-terra",
                ),
            )
            assertEquals(expected, assertIs<Outcome.Success<EnvironmentConfig>>(result).value.environment)
        }
    }

    @Test
    fun rejectsMissingOrEmptyEnvironment() {
        for (environment in listOf(null, "", " ")) {
            val variables = environment?.let { arrayOf("AI_APPS_ENV" to it) } ?: emptyArray()
            val result = EnvironmentConfig.load(
                reader(*variables, "AI_APPS_AI_BASE_URL" to "https://example.com"),
            )
            assertEquals(
                ConfigError.MissingOrEmpty("AI_APPS_ENV"),
                assertIs<Outcome.Failure<ConfigError>>(result).error,
            )
        }
    }

    @Test
    fun rejectsInvalidEnvironment() {
        val result = EnvironmentConfig.load(
            reader("AI_APPS_ENV" to "staging", "AI_APPS_AI_BASE_URL" to "https://example.com"),
        )

        assertEquals(
            ConfigError.InvalidValue("AI_APPS_ENV", "staging"),
            assertIs<Outcome.Failure<ConfigError>>(result).error,
        )
    }

    @Test
    fun rejectsMissingOrEmptyAiBaseUrl() {
        for (url in listOf(null, "", " ")) {
            val variables = url?.let { arrayOf("AI_APPS_AI_BASE_URL" to it) } ?: emptyArray()
            val result = EnvironmentConfig.load(reader("AI_APPS_ENV" to "test", *variables))
            assertEquals(
                ConfigError.MissingOrEmpty("AI_APPS_AI_BASE_URL"),
                assertIs<Outcome.Failure<ConfigError>>(result).error,
            )
        }
    }

    @Test
    fun rejectsInvalidAiBaseUrl() {
        for (url in listOf("not a uri", "/relative", "ftp://example.com", "https:/no-host")) {
            val result = EnvironmentConfig.load(
                reader("AI_APPS_ENV" to "test", "AI_APPS_AI_BASE_URL" to url),
            )
            assertEquals(
                ConfigError.InvalidValue("AI_APPS_AI_BASE_URL", url),
                assertIs<Outcome.Failure<ConfigError>>(result).error,
            )
        }
    }

    @Test
    fun rejectsMissingEmptyAndWhitespaceOnlyApiKey() {
        for (key in listOf(null, "", " ")) {
            val apiKey = key?.let { arrayOf("AI_APPS_AI_API_KEY" to it) } ?: emptyArray()
            val result = EnvironmentConfig.load(
                reader(
                    "AI_APPS_ENV" to "test",
                    "AI_APPS_AI_BASE_URL" to "https://example.com",
                    *apiKey,
                ),
            )
            assertEquals(
                ConfigError.MissingOrEmpty("AI_APPS_AI_API_KEY"),
                assertIs<Outcome.Failure<ConfigError>>(result).error,
            )
        }
    }
    @Test
    fun rejectsMissingEmptyAndWhitespaceOnlyModels() {
        val modelKeys = listOf("AI_APPS_AI_LUNA_MODEL", "AI_APPS_AI_MINI_MODEL", "AI_APPS_AI_TERRA_MODEL")
        for (key in modelKeys) {
            for (value in listOf(null, "", " ", "\t\n")) {
                val variables = mutableMapOf(
                    "AI_APPS_ENV" to "test",
                    "AI_APPS_AI_BASE_URL" to "https://example.com",
                    "AI_APPS_AI_API_KEY" to "example-test-key",
                )
                modelKeys.forEach { variables[it] = "configured-model" }
                if (value == null) variables.remove(key) else variables[key] = value

                val result = EnvironmentConfig.load(EnvironmentReader { variables[it] })

                assertEquals(
                    ConfigError.MissingOrEmpty(key),
                    assertIs<Outcome.Failure<ConfigError>>(result).error,
                )
            }
        }
    }
}
