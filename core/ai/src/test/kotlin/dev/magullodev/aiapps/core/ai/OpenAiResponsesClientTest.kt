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
    private val request = StructuredGenerationRequest("model-a", "Answer briefly", "answer_schema", schema)
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
    fun sendsRequestedModelToAuthenticatedResponsesEndpoint() {
        val transport = transport()

        OpenAiResponsesClient(config, transport).generate(request)

        val sent = transport.request
        val body = Json.parseToJsonElement(requireNotNull(sent.body)).jsonObject
        assertEquals(HttpMethod.POST, sent.method)
        assertEquals(URI("https://api.example.test/v1/responses"), sent.uri)
        assertEquals(request.model, body["model"]?.jsonPrimitive?.content)
        assertEquals("Answer briefly", body["input"]?.jsonPrimitive?.content)
        assertEquals("Bearer example-test-key", sent.headers["Authorization"])
        assertEquals("application/json", sent.headers["Content-Type"])
    }

    @Test
    fun consecutiveRequestsCanUseDifferentModelsWithTheSameConfiguration() {
        val transport = transport()
        val client = OpenAiResponsesClient(config, transport)

        client.generate(request)
        val firstBody = Json.parseToJsonElement(requireNotNull(transport.request.body)).jsonObject
        assertEquals(request.model, firstBody["model"]?.jsonPrimitive?.content)

        val secondRequest = request.copy(model = "model-b")
        client.generate(secondRequest)
        val secondBody = Json.parseToJsonElement(requireNotNull(transport.request.body)).jsonObject
        assertEquals(secondRequest.model, secondBody["model"]?.jsonPrimitive?.content)
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
        val transport = ControlledTransport(Outcome.Failure(NetworkError.TransportFailure(IOException("connection failed"))))

        val result = OpenAiResponsesClient(config, transport).generate(request)

        assertEquals(AiError.TransportFailure, assertIs<Outcome.Failure<AiError>>(result).error)
    }

    @Test
    fun rejectsMalformedSchemaBeforeSending() {
        val transport = transport()

        val result = OpenAiResponsesClient(config, transport).generate(request.copy(schemaJson = "{bad"))

        assertEquals(AiError.InvalidSchemaJson, assertIs<Outcome.Failure<AiError>>(result).error)
    }
}
