package dev.magullodev.aiapps.ai

import dev.magullodev.aiapps.core.config.AiModelsConfig
import dev.magullodev.aiapps.core.config.AppEnvironment
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.HttpRequest
import dev.magullodev.aiapps.core.network.HttpResponse
import dev.magullodev.aiapps.core.network.HttpTransport
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest as JdkRequest
import java.net.http.HttpResponse as JdkResponse
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals

class AiHttpServerTest {
    @Test
    fun authenticatedGameRequestReachesSelectedModelWithoutExposingApiKey() {
        var sent: HttpRequest? = null
        val transport = HttpTransport { request ->
            sent = request
            Outcome.Success(HttpResponse(200, emptyMap(),
                """{"output":[{"content":[{"type":"output_text","text":"{\"answer\":\"ok\"}"}]}]}"""))
        }
        val config = EnvironmentConfig(AppEnvironment.TEST, URI("https://api.openai.com"),
            "private-openai-key", AiModelsConfig("old-luna", "old-mini", "old-terra"))
        val server = AiHttpServer.create(0, "local-test-token", OpenAiResponsesClient(config, transport))
        server.start()
        try {
            val endpoint = URI("http://127.0.0.1:${server.address.port}/v1/generate")
            val body = """{"application":"molecular","model":"chosen-model","input":"hello","schemaName":"answer","schema":{"type":"object"}}"""
            fun send(token: String) = HttpClient.newHttpClient().send(
                JdkRequest.newBuilder(endpoint).header("Authorization", "Bearer $token")
                    .header("Content-Type", "application/json").POST(JdkRequest.BodyPublishers.ofString(body)).build(),
                JdkResponse.BodyHandlers.ofString(),
            )
            assertEquals(401, send("wrong-token").statusCode())
            assertEquals(200, send("local-test-token").statusCode())
            val outgoing = Json.parseToJsonElement(requireNotNull(sent?.body)).jsonObject
            assertEquals("chosen-model", outgoing["model"]?.jsonPrimitive?.content)
        } finally {
            server.stop(0)
        }
    }
}
