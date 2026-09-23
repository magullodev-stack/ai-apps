package dev.magullodev.aiapps.core.config

import dev.magullodev.aiapps.core.contracts.Outcome
import java.net.URI
import java.net.URISyntaxException

data class EnvironmentConfig(
    val environment: AppEnvironment,
    val aiBaseUrl: URI,
    val aiApiKey: String,
    val aiModels: AiModelsConfig,
) {
    override fun toString(): String =
        "EnvironmentConfig(" +
            "environment=$environment, " +
            "aiBaseUrl=$aiBaseUrl, " +
            "aiApiKey=[REDACTED], " +
            "aiModels=$aiModels)"

    companion object {
        fun load(reader: EnvironmentReader = SystemEnvironmentReader): Outcome<EnvironmentConfig, ConfigError> {
            val environmentValue = reader.get("AI_APPS_ENV")
            if (environmentValue.isNullOrBlank()) {
                return Outcome.Failure(ConfigError.MissingOrEmpty("AI_APPS_ENV"))
            }

            val environment = when (environmentValue) {
                "development" -> AppEnvironment.DEVELOPMENT
                "test" -> AppEnvironment.TEST
                "production" -> AppEnvironment.PRODUCTION
                else -> return Outcome.Failure(ConfigError.InvalidValue("AI_APPS_ENV", environmentValue))
            }

            val urlValue = reader.get("AI_APPS_AI_BASE_URL")
            if (urlValue.isNullOrBlank()) {
                return Outcome.Failure(ConfigError.MissingOrEmpty("AI_APPS_AI_BASE_URL"))
            }

            val url = try {
                URI(urlValue)
            } catch (_: URISyntaxException) {
                return Outcome.Failure(ConfigError.InvalidValue("AI_APPS_AI_BASE_URL", urlValue))
            }

            if (
                !url.isAbsolute ||
                !(url.scheme.equals("http", ignoreCase = true) || url.scheme.equals("https", ignoreCase = true)) ||
                url.host.isNullOrBlank()
            ) {
                return Outcome.Failure(ConfigError.InvalidValue("AI_APPS_AI_BASE_URL", urlValue))
            }

            val apiKey = reader.get("AI_APPS_AI_API_KEY")
            if (apiKey.isNullOrBlank()) {
                return Outcome.Failure(ConfigError.MissingOrEmpty("AI_APPS_AI_API_KEY"))
            }

            val luna = reader.get("AI_APPS_AI_LUNA_MODEL")
            if (luna.isNullOrBlank()) {
                return Outcome.Failure(ConfigError.MissingOrEmpty("AI_APPS_AI_LUNA_MODEL"))
            }

            val mini = reader.get("AI_APPS_AI_MINI_MODEL")
            if (mini.isNullOrBlank()) {
                return Outcome.Failure(ConfigError.MissingOrEmpty("AI_APPS_AI_MINI_MODEL"))
            }

            val terra = reader.get("AI_APPS_AI_TERRA_MODEL")
            if (terra.isNullOrBlank()) {
                return Outcome.Failure(ConfigError.MissingOrEmpty("AI_APPS_AI_TERRA_MODEL"))
            }

            return Outcome.Success(EnvironmentConfig(environment, url, apiKey, AiModelsConfig(luna, mini, terra)))
        }
    }
}
