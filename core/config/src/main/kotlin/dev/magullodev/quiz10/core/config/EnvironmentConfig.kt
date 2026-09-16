package dev.magullodev.quiz10.core.config

import dev.magullodev.quiz10.core.contracts.Outcome
import java.net.URI
import java.net.URISyntaxException

data class EnvironmentConfig(
    val environment: AppEnvironment,
    val aiBaseUrl: URI,
    val aiPlannerModel: String,
    val aiTurnModel: String,
    val aiApiKey: String,
) {
    override fun toString(): String =
        "EnvironmentConfig(" +
            "environment=$environment, " +
            "aiBaseUrl=$aiBaseUrl, " +
            "aiPlannerModel=$aiPlannerModel, " +
            "aiTurnModel=$aiTurnModel, " +
            "aiApiKey=[REDACTED])"

    companion object {
        fun load(reader: EnvironmentReader = SystemEnvironmentReader): Outcome<EnvironmentConfig, ConfigError> {
            val environmentValue = reader.get("QUIZ10_ENV")
            if (environmentValue.isNullOrBlank()) {
                return Outcome.Failure(ConfigError.MissingOrEmpty("QUIZ10_ENV"))
            }

            val environment = when (environmentValue) {
                "development" -> AppEnvironment.DEVELOPMENT
                "test" -> AppEnvironment.TEST
                "production" -> AppEnvironment.PRODUCTION
                else -> return Outcome.Failure(ConfigError.InvalidValue("QUIZ10_ENV", environmentValue))
            }

            val urlValue = reader.get("QUIZ10_AI_BASE_URL")
            if (urlValue.isNullOrBlank()) {
                return Outcome.Failure(ConfigError.MissingOrEmpty("QUIZ10_AI_BASE_URL"))
            }

            val url = try {
                URI(urlValue)
            } catch (_: URISyntaxException) {
                return Outcome.Failure(ConfigError.InvalidValue("QUIZ10_AI_BASE_URL", urlValue))
            }

            if (
                !url.isAbsolute ||
                !(url.scheme.equals("http", ignoreCase = true) || url.scheme.equals("https", ignoreCase = true)) ||
                url.host.isNullOrBlank()
            ) {
                return Outcome.Failure(ConfigError.InvalidValue("QUIZ10_AI_BASE_URL", urlValue))
            }

            val plannerModel = reader.get("QUIZ10_AI_PLANNER_MODEL")
            if (plannerModel.isNullOrBlank()) {
                return Outcome.Failure(ConfigError.MissingOrEmpty("QUIZ10_AI_PLANNER_MODEL"))
            }

            val turnModel = reader.get("QUIZ10_AI_TURN_MODEL")
            if (turnModel.isNullOrBlank()) {
                return Outcome.Failure(ConfigError.MissingOrEmpty("QUIZ10_AI_TURN_MODEL"))
            }

            val apiKey = reader.get("QUIZ10_AI_API_KEY")
            if (apiKey.isNullOrBlank()) {
                return Outcome.Failure(ConfigError.MissingOrEmpty("QUIZ10_AI_API_KEY"))
            }

            return Outcome.Success(EnvironmentConfig(environment, url, plannerModel, turnModel, apiKey))
        }
    }
}
