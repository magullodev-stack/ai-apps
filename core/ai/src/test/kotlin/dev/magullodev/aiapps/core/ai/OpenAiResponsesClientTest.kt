package dev.magullodev.aiapps.core.ai

import dev.magullodev.aiapps.core.config.AiModelsConfig
import dev.magullodev.aiapps.core.config.AppEnvironment
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.HttpMethod
import dev.magullodev.aiapps.core.network.HttpRequest
import dev.magullodev.aiapps.core.network.HttpResponse
import dev.magullodev.aiapps.core.network.HttpTransport
import dev.magullodev.aiapps.core.network.NetworkError
import dev.magullodev.aiapps.core.network.NetworkTransportFailureKind
import java.io.IOException
import java.net.URI
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class OpenAiResponsesClientTest {
    private val config = EnvironmentConfig(
        AppEnvironment.TEST,
        URI("https://api.example.test/base/"),
        "example-test-key",
        AiModelsConfig("model-luna", "model-mini", "model-terra"),
    )
    private val schema = """{"type":"object","properties":{"answer":{"type":"string"}},"required":["answer"],"additionalProperties":false}"""
    private val request = StructuredGenerationRequest(AiProfile.LUNA, "Answer briefly", "answer_schema", schema)
    private val outputText = """{"answer":"ok"}"""
    private val envelope = """{"output":[{"type":"reasoning","summary":[]},{"type":"message","content":[{"type":"output_text","text":"{\"answer\":\"ok\"}"}]}],"usage":{"input_tokens":12,"output_tokens":5,"total_tokens":17}}"""

    private class ControlledTransport(
        var result: Outcome<HttpResponse, NetworkError>,
    ) : HttpTransport {
        lateinit var request: HttpRequest

        override fun execute(request: HttpRequest): Outcome<HttpResponse, NetworkError> {
            this.request = request
            return result
        }
    }

    private fun transport(body: String = envelope, status: Int = 200) =
        ControlledTransport(Outcome.Success(HttpResponse(status, emptyMap(), body)))

    @Test
    fun sendsResolvedModelToAuthenticatedResponsesEndpoint() {
        val transport = transport()

        OpenAiResponsesClient(config, transport).generate(request)

        val sent = transport.request
        val body = Json.parseToJsonElement(requireNotNull(sent.body)).jsonObject
        assertEquals(HttpMethod.POST, sent.method)
        assertEquals(URI("https://api.example.test/v1/responses"), sent.uri)
        assertEquals("model-luna", body["model"]?.jsonPrimitive?.content)
        assertEquals("Answer briefly", body["input"]?.jsonPrimitive?.content)
        assertEquals("Bearer example-test-key", sent.headers["Authorization"])
        assertEquals("application/json", sent.headers["Content-Type"])
    }

    @Test
    fun sameClientResolvesAllGlobalProfilesFromConfiguration() {
        val transport = transport()
        val client = OpenAiResponsesClient(config, transport)
        val expectedModels = mapOf(
            AiProfile.LUNA to "model-luna",
            AiProfile.MINI to "model-mini",
            AiProfile.TERRA to "model-terra",
        )

        for ((profile, expectedModel) in expectedModels) {
            assertIs<Outcome.Success<StructuredGeneration>>(client.generate(request.copy(profile = profile)))
            val body = Json.parseToJsonElement(requireNotNull(transport.request.body)).jsonObject
            assertEquals(expectedModel, body["model"]?.jsonPrimitive?.content)
        }
    }

    @Test
    fun requestContainsStrictJsonSchemaFormat() {
        val transport = transport()

        OpenAiResponsesClient(config, transport).generate(request)

        val body = Json.parseToJsonElement(requireNotNull(transport.request.body)).jsonObject
        val format = body["text"]!!.jsonObject["format"]!!.jsonObject
        assertEquals("json_schema", format["type"]?.jsonPrimitive?.content)
        assertEquals("answer_schema", format["name"]?.jsonPrimitive?.content)
        assertEquals("true", format["strict"]?.jsonPrimitive?.content)
        assertEquals(Json.parseToJsonElement(schema), format["schema"])
    }

    @Test
    fun extractsOutputTextAndUsageFromResponsesEnvelope() {
        val result = OpenAiResponsesClient(config, transport()).generate(request)

        val value = assertIs<Outcome.Success<StructuredGeneration>>(result).value
        assertEquals(outputText, value.text)
        assertEquals(TokenUsage(12, 5, 17), value.usage)
    }

    @Test
    fun returnsTypedErrorForNonSuccessHttpStatus() {
        val result = OpenAiResponsesClient(config, transport("""{"error":"not exposed"}""", 429)).generate(request)

        assertEquals(AiError.HttpFailure(429), assertIs<Outcome.Failure<AiError>>(result).error)
    }

    @Test
    fun returnsTypedErrorWhenOutputTextIsMissing() {
        val result = OpenAiResponsesClient(config, transport("""{"output":[{"type":"reasoning","summary":[]}]}"""))
            .generate(request)

        assertEquals(AiError.MissingOutputText, assertIs<Outcome.Failure<AiError>>(result).error)
    }

    @Test
    fun returnsTypedErrorForMalformedResponseJson() {
        val result = OpenAiResponsesClient(config, transport("{bad")).generate(request)

        assertEquals(AiError.InvalidResponseJson, assertIs<Outcome.Failure<AiError>>(result).error)
    }

    @Test
    fun returnsTypedErrorForTransportFailure() {
        val transport = ControlledTransport(
            Outcome.Failure(
                NetworkError.TransportFailure(
                    cause = IOException("connect timed out"),
                    kind = NetworkTransportFailureKind.CONNECT_TIMEOUT,
                ),
            ),
        )

        val result = OpenAiResponsesClient(config, transport).generate(request)

        val error = assertIs<Outcome.Failure<AiError>>(result).error
        val diagnosed = assertIs<AiError.TransportFailureDiagnosed>(error)
        assertEquals(AiTransportFailureKind.CONNECT_TIMEOUT, diagnosed.kind)
        assertEquals("IOException: connect timed out", diagnosed.detail)
    }

    @Test
    fun mapsReadTimeoutAndInvalidRequestTransportFailures() {
        val readTimeoutTransport = ControlledTransport(
            Outcome.Failure(
                NetworkError.TransportFailure(
                    cause = IOException("Read timed out"),
                    kind = NetworkTransportFailureKind.READ_TIMEOUT,
                ),
            ),
        )
        val invalidRequestTransport = ControlledTransport(
            Outcome.Failure(NetworkError.InvalidRequest("URI must be absolute HTTP(S) with a host")),
        )

        val readTimeoutResult = OpenAiResponsesClient(config, readTimeoutTransport).generate(request)
        val invalidRequestResult = OpenAiResponsesClient(config, invalidRequestTransport).generate(request)

        val readTimeoutError = assertIs<AiError.TransportFailureDiagnosed>(
            assertIs<Outcome.Failure<AiError>>(readTimeoutResult).error,
        )
        assertEquals(AiTransportFailureKind.READ_TIMEOUT, readTimeoutError.kind)
        assertEquals("IOException: Read timed out", readTimeoutError.detail)

        val invalidRequestError = assertIs<AiError.TransportFailureDiagnosed>(
            assertIs<Outcome.Failure<AiError>>(invalidRequestResult).error,
        )
        assertEquals(AiTransportFailureKind.INVALID_REQUEST, invalidRequestError.kind)
        assertEquals("URI must be absolute HTTP(S) with a host", invalidRequestError.detail)
    }

    @Test
    fun rejectsMalformedSchemaBeforeSending() {
        val transport = transport()

        val result = OpenAiResponsesClient(config, transport).generate(request.copy(schemaJson = "{bad"))

        assertEquals(AiError.InvalidSchemaJson, assertIs<Outcome.Failure<AiError>>(result).error)
    }
}
