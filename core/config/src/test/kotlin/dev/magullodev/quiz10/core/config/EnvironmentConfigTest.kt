package dev.magullodev.quiz10.core.config

import dev.magullodev.quiz10.core.contracts.Outcome
import java.net.URI
import kotlin.test.Test
import kotlin.test.assertEquals
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
                "QUIZ10_ENV" to "production",
                "QUIZ10_AI_BASE_URL" to "https://example.com/api",
                "QUIZ10_AI_PLANNER_MODEL" to "planner-v1",
                "QUIZ10_AI_TURN_MODEL" to "turn-v1",
            ),
        )

        val config = assertIs<Outcome.Success<EnvironmentConfig>>(result).value
        assertEquals(AppEnvironment.PRODUCTION, config.environment)
        assertEquals(URI("https://example.com/api"), config.aiBaseUrl)
        assertEquals("planner-v1", config.aiPlannerModel)
        assertEquals("turn-v1", config.aiTurnModel)
    }

    @Test
    fun acceptsUppercaseHttpScheme() {
        val result = EnvironmentConfig.load(
            reader(
                "QUIZ10_ENV" to "test",
                "QUIZ10_AI_BASE_URL" to "HTTP://example.com",
                "QUIZ10_AI_PLANNER_MODEL" to "planner",
                "QUIZ10_AI_TURN_MODEL" to "turn",
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
                    "QUIZ10_ENV" to name,
                    "QUIZ10_AI_BASE_URL" to "http://localhost:8080",
                    "QUIZ10_AI_PLANNER_MODEL" to "planner",
                    "QUIZ10_AI_TURN_MODEL" to "turn",
                ),
            )
            assertEquals(expected, assertIs<Outcome.Success<EnvironmentConfig>>(result).value.environment)
        }
    }

    @Test
    fun rejectsMissingOrEmptyEnvironment() {
        for (environment in listOf(null, "", " ")) {
            val variables = environment?.let { arrayOf("QUIZ10_ENV" to it) } ?: emptyArray()
            val result = EnvironmentConfig.load(
                reader(*variables, "QUIZ10_AI_BASE_URL" to "https://example.com"),
            )
            assertEquals(
                ConfigError.MissingOrEmpty("QUIZ10_ENV"),
                assertIs<Outcome.Failure<ConfigError>>(result).error,
            )
        }
    }

    @Test
    fun rejectsInvalidEnvironment() {
        val result = EnvironmentConfig.load(
            reader("QUIZ10_ENV" to "staging", "QUIZ10_AI_BASE_URL" to "https://example.com"),
        )

        assertEquals(
            ConfigError.InvalidValue("QUIZ10_ENV", "staging"),
            assertIs<Outcome.Failure<ConfigError>>(result).error,
        )
    }

    @Test
    fun rejectsMissingOrEmptyAiBaseUrl() {
        for (url in listOf(null, "", " ")) {
            val variables = url?.let { arrayOf("QUIZ10_AI_BASE_URL" to it) } ?: emptyArray()
            val result = EnvironmentConfig.load(reader("QUIZ10_ENV" to "test", *variables))
            assertEquals(
                ConfigError.MissingOrEmpty("QUIZ10_AI_BASE_URL"),
                assertIs<Outcome.Failure<ConfigError>>(result).error,
            )
        }
    }

    @Test
    fun rejectsInvalidAiBaseUrl() {
        for (url in listOf("not a uri", "/relative", "ftp://example.com", "https:/no-host")) {
            val result = EnvironmentConfig.load(
                reader("QUIZ10_ENV" to "test", "QUIZ10_AI_BASE_URL" to url),
            )
            assertEquals(
                ConfigError.InvalidValue("QUIZ10_AI_BASE_URL", url),
                assertIs<Outcome.Failure<ConfigError>>(result).error,
            )
        }
    }

    @Test
    fun rejectsMissingOrEmptyPlannerModel() {
        for (model in listOf(null, "", " ")) {
            val planner = model?.let { arrayOf("QUIZ10_AI_PLANNER_MODEL" to it) } ?: emptyArray()
            val result = EnvironmentConfig.load(
                reader(
                    "QUIZ10_ENV" to "test",
                    "QUIZ10_AI_BASE_URL" to "https://example.com",
                    *planner,
                    "QUIZ10_AI_TURN_MODEL" to "turn",
                ),
            )
            assertEquals(
                ConfigError.MissingOrEmpty("QUIZ10_AI_PLANNER_MODEL"),
                assertIs<Outcome.Failure<ConfigError>>(result).error,
            )
        }
    }

    @Test
    fun rejectsMissingOrEmptyTurnModel() {
        for (model in listOf(null, "", " ")) {
            val turn = model?.let { arrayOf("QUIZ10_AI_TURN_MODEL" to it) } ?: emptyArray()
            val result = EnvironmentConfig.load(
                reader(
                    "QUIZ10_ENV" to "test",
                    "QUIZ10_AI_BASE_URL" to "https://example.com",
                    "QUIZ10_AI_PLANNER_MODEL" to "planner",
                    *turn,
                ),
            )
            assertEquals(
                ConfigError.MissingOrEmpty("QUIZ10_AI_TURN_MODEL"),
                assertIs<Outcome.Failure<ConfigError>>(result).error,
            )
        }
    }
}
