package dev.magullodev.aiapps.ai

import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.HttpMethod
import dev.magullodev.aiapps.core.network.HttpRequest
import dev.magullodev.aiapps.core.network.HttpTransport
import dev.magullodev.aiapps.core.network.NetworkError
import dev.magullodev.aiapps.core.network.NetworkTransportFailureKind
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
    private val usageMonitor: AiUsageMonitor = AiUsageMonitor.NOOP,
) {
    fun generate(request: StructuredGenerationRequest): Outcome<StructuredGeneration, AiError> {
        val startedNanos = System.nanoTime()
        val schema = try {
            Json.parseToJsonElement(request.schemaJson) as? JsonObject
        } catch (_: SerializationException) {
            null
        } ?: return fail(request, startedNanos, AiError.InvalidSchemaJson)

        val model = request.model?.takeIf { it.isNotBlank() } ?: when (request.profile) {
            AiProfile.LUNA -> config.aiModels.luna
            AiProfile.MINI -> config.aiModels.mini
            AiProfile.TERRA -> config.aiModels.terra
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
            is Outcome.Failure -> return fail(request, startedNanos, toAiTransportFailure(result.error))
        }
        if (response.status !in 200..299) {
            return fail(request, startedNanos, AiError.HttpFailure(response.status))
        }

        val envelope = try {
            Json.parseToJsonElement(response.body) as? JsonObject
        } catch (_: SerializationException) {
            null
        } ?: return fail(request, startedNanos, AiError.InvalidResponseJson)

        val output = envelope["output"] as? JsonArray
            ?: return fail(request, startedNanos, AiError.InvalidResponseJson)
        var outputText: String? = null
        for (item in output) {
            val content = (item as? JsonObject)?.get("content") as? JsonArray ?: continue
            for (part in content) {
                val fields = part as? JsonObject ?: continue
                if ((fields["type"] as? JsonPrimitive)?.content != "output_text") continue
                val text = fields["text"] as? JsonPrimitive
                    ?: return fail(request, startedNanos, AiError.InvalidResponseJson)
                if (!text.isString) return fail(request, startedNanos, AiError.InvalidResponseJson)
                outputText = text.content
                break
            }
            if (outputText != null) break
        }
        if (outputText == null) return fail(request, startedNanos, AiError.MissingOutputText)

        val usageObject = when (val value = envelope["usage"]) {
            null, JsonNull -> null
            is JsonObject -> value
            else -> return fail(request, startedNanos, AiError.InvalidResponseJson)
        }
        val usage = usageObject?.let { fields ->
            val names = listOf("input_tokens", "output_tokens", "total_tokens")
            if (names.any { name ->
                    fields[name] != null && (fields[name] as? JsonPrimitive)?.longOrNull == null
                }) {
                return fail(request, startedNanos, AiError.InvalidResponseJson)
            }
            TokenUsage(
                fields["input_tokens"]?.let { (it as JsonPrimitive).longOrNull },
                fields["output_tokens"]?.let { (it as JsonPrimitive).longOrNull },
                fields["total_tokens"]?.let { (it as JsonPrimitive).longOrNull },
            )
        }

        return succeed(request, startedNanos, StructuredGeneration(outputText, usage))
    }

    private fun fail(
        request: StructuredGenerationRequest,
        startedNanos: Long,
        error: AiError,
    ): Outcome<StructuredGeneration, AiError> {
        recordCall(request, startedNanos, AiUsageCallResult.ERROR, usage = null, error = error)
        return Outcome.Failure(error)
    }

    private fun succeed(
        request: StructuredGenerationRequest,
        startedNanos: Long,
        generation: StructuredGeneration,
    ): Outcome<StructuredGeneration, AiError> {
        recordCall(request, startedNanos, AiUsageCallResult.SUCCESS, usage = generation.usage, error = null)
        return Outcome.Success(generation)
    }

    private fun recordCall(
        request: StructuredGenerationRequest,
        startedNanos: Long,
        result: AiUsageCallResult,
        usage: TokenUsage?,
        error: AiError?,
    ) {
        val model = request.model?.takeIf { it.isNotBlank() } ?: when (request.profile) {
            AiProfile.LUNA -> config.aiModels.luna
            AiProfile.MINI -> config.aiModels.mini
            AiProfile.TERRA -> config.aiModels.terra
        }
        val context = AiUsageContextHolder.current()
        usageMonitor.recordCall(
            AiUsageCallEvent(
                application = context?.application ?: "unknown-app",
                operation = request.operation ?: AiUsageOperation.OTHER,
                model = model,
                durationMillis = (System.nanoTime() - startedNanos).coerceAtLeast(0) / 1_000_000,
                result = result,
                workUnitId = context?.workUnitId,
                inputTokens = usage?.inputTokens,
                outputTokens = usage?.outputTokens,
                totalTokens = usage?.totalTokens,
                usageKnown = usage != null,
                errorCode = error?.let(::safeErrorCode),
            ),
        )
    }

    private fun safeErrorCode(error: AiError): String = when (error) {
        AiError.InvalidSchemaJson -> "AiError.InvalidSchemaJson"
        AiError.TransportFailure -> "AiError.TransportFailure"
        is AiError.TransportFailureDiagnosed -> "AiError.TransportFailure(${error.kind})"
        is AiError.HttpFailure -> "AiError.HttpFailure(${error.status})"
        AiError.InvalidResponseJson -> "AiError.InvalidResponseJson"
        AiError.MissingOutputText -> "AiError.MissingOutputText"
    }

    private fun toAiTransportFailure(error: NetworkError): AiError = when (error) {
        is NetworkError.InvalidRequest -> AiError.TransportFailureDiagnosed(
            kind = AiTransportFailureKind.INVALID_REQUEST,
            detail = limitDiagnostic(error.reason),
        )

        is NetworkError.TransportFailure -> {
            val kind = when (error.kind) {
                NetworkTransportFailureKind.CONNECT_TIMEOUT -> AiTransportFailureKind.CONNECT_TIMEOUT
                NetworkTransportFailureKind.READ_TIMEOUT -> AiTransportFailureKind.READ_TIMEOUT
                NetworkTransportFailureKind.IO -> AiTransportFailureKind.IO
            }
            val message = error.cause.message?.trim().orEmpty()
            val detail = if (message.isEmpty()) {
                error.cause::class.simpleName ?: "IOException"
            } else {
                "${error.cause::class.simpleName ?: "IOException"}: $message"
            }
            AiError.TransportFailureDiagnosed(kind = kind, detail = limitDiagnostic(detail))
        }
    }

    private fun limitDiagnostic(value: String): String {
        val sanitized = value.replace(Regex("\\s+"), " ").trim()
        return if (sanitized.length <= 180) sanitized else sanitized.take(180)
    }
}
