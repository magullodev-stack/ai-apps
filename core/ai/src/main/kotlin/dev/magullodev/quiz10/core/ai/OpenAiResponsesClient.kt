package dev.magullodev.quiz10.core.ai

import dev.magullodev.quiz10.core.config.EnvironmentConfig
import dev.magullodev.quiz10.core.contracts.Outcome
import dev.magullodev.quiz10.core.network.HttpMethod
import dev.magullodev.quiz10.core.network.HttpRequest
import dev.magullodev.quiz10.core.network.HttpTransport
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.longOrNull
import kotlinx.serialization.json.put

class OpenAiResponsesClient(
    private val config: EnvironmentConfig,
    private val transport: HttpTransport,
) {
    fun generate(request: StructuredGenerationRequest): Outcome<StructuredGeneration, AiError> {
        val schema = try {
            Json.parseToJsonElement(request.schemaJson) as? JsonObject
        } catch (_: SerializationException) {
            null
        } ?: return Outcome.Failure(AiError.InvalidSchemaJson)

        val model = when (request.profile) {
            GenerationProfile.PLANNER -> config.aiPlannerModel
            GenerationProfile.TURN -> config.aiTurnModel
        }
        val body = buildJsonObject {
            put("model", model)
            put("input", request.input)
            put("text", buildJsonObject {
                put("format", buildJsonObject {
                    put("type", "json_schema")
                    put("name", request.schemaName)
                    put("strict", true)
                    put("schema", schema)
                })
            })
        }.toString()
        val httpRequest = HttpRequest(
            method = HttpMethod.POST,
            uri = config.aiBaseUrl.resolve("/v1/responses"),
            headers = mapOf(
                "Authorization" to "Bearer ${config.aiApiKey}",
                "Content-Type" to "application/json",
            ),
            body = body,
        )

        val response = when (val result = transport.execute(httpRequest)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> return Outcome.Failure(AiError.TransportFailure)
        }
        if (response.status !in 200..299) {
            return Outcome.Failure(AiError.HttpFailure(response.status))
        }

        val envelope = try {
            Json.parseToJsonElement(response.body) as? JsonObject
        } catch (_: SerializationException) {
            null
        } ?: return Outcome.Failure(AiError.InvalidResponseJson)

        val output = envelope["output"] as? JsonArray
            ?: return Outcome.Failure(AiError.InvalidResponseJson)
        var outputText: String? = null
        for (item in output) {
            val content = (item as? JsonObject)?.get("content") as? JsonArray ?: continue
            for (part in content) {
                val fields = part as? JsonObject ?: continue
                if ((fields["type"] as? JsonPrimitive)?.content != "output_text") continue
                val text = fields["text"] as? JsonPrimitive
                    ?: return Outcome.Failure(AiError.InvalidResponseJson)
                if (!text.isString) return Outcome.Failure(AiError.InvalidResponseJson)
                outputText = text.content
                break
            }
            if (outputText != null) break
        }
        if (outputText == null) return Outcome.Failure(AiError.MissingOutputText)

        val usageObject = when (val value = envelope["usage"]) {
            null, JsonNull -> null
            is JsonObject -> value
            else -> return Outcome.Failure(AiError.InvalidResponseJson)
        }
        val usage = usageObject?.let { fields ->
            val names = listOf("input_tokens", "output_tokens", "total_tokens")
            if (names.any { name ->
                    fields[name] != null && (fields[name] as? JsonPrimitive)?.longOrNull == null
                }) {
                return Outcome.Failure(AiError.InvalidResponseJson)
            }
            TokenUsage(
                fields["input_tokens"]?.let { (it as JsonPrimitive).longOrNull },
                fields["output_tokens"]?.let { (it as JsonPrimitive).longOrNull },
                fields["total_tokens"]?.let { (it as JsonPrimitive).longOrNull },
            )
        }

        return Outcome.Success(StructuredGeneration(outputText, usage))
    }
}
