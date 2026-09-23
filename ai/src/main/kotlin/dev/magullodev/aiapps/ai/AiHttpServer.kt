package dev.magullodev.aiapps.ai

import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import dev.magullodev.aiapps.core.config.AiModelsConfig
import dev.magullodev.aiapps.core.config.AppEnvironment
import dev.magullodev.aiapps.core.config.EnvironmentConfig
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.core.network.UrlConnectionHttpTransport
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.URI
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.concurrent.Executors
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/** Local development bridge for mobile games. Keep OpenAI credentials on this process. */
object AiHttpServer {
    @JvmStatic
    fun main(args: Array<String>) {
        val key = requireNotNull(System.getenv("AI_APPS_AI_API_KEY")?.takeIf(String::isNotBlank))
        val token = requireNotNull(System.getenv("AI_APPS_GAME_TOKEN")?.takeIf(String::isNotBlank))
        val base = URI(System.getenv("AI_APPS_AI_BASE_URL") ?: "https://api.openai.com")
        require(base.scheme == "https" || (base.scheme == "http" && base.host in setOf("localhost", "127.0.0.1")))
        val port = (System.getenv("AI_APPS_GAME_PORT") ?: "8787").toInt()
        val fallback = System.getenv("AI_APPS_AI_MODEL")?.takeIf(String::isNotBlank).orEmpty()
        val config = EnvironmentConfig(AppEnvironment.DEVELOPMENT, base, key, AiModelsConfig(fallback, fallback, fallback))
        val client = OpenAiResponsesClient(config, UrlConnectionHttpTransport(5_000, 60_000),
            FileAiUsageMonitor(resolveUsageFile(), loadModelRates()))
        val server = create(port, token, client)
        server.start()
        println("AI-APPS IA disponible en 127.0.0.1:$port")
    }

    internal fun create(port: Int, token: String, client: OpenAiResponsesClient): HttpServer {
        require(token.isNotBlank())
        val server = HttpServer.create(InetSocketAddress(InetAddress.getByName("127.0.0.1"), port), 0)
        server.executor = Executors.newFixedThreadPool(4) { task ->
            Thread(task, "ai-http").apply { isDaemon = true }
        }
        server.createContext("/v1/generate") { exchange -> handle(exchange, token, client) }
        return server
    }

    private fun handle(exchange: HttpExchange, token: String, client: OpenAiResponsesClient) {
        try {
            if (exchange.requestMethod != "POST") return send(exchange, 405, "method_not_allowed")
            val expected = "Bearer $token".toByteArray(StandardCharsets.UTF_8)
            val actual = exchange.requestHeaders.getFirst("Authorization")?.toByteArray(StandardCharsets.UTF_8)
            if (actual == null || !MessageDigest.isEqual(expected, actual)) return send(exchange, 401, "unauthorized")
            val bytes = exchange.requestBody.use { it.readNBytes(65_537) }
            if (bytes.size > 65_536) return send(exchange, 413, "request_too_large")
            val body = try { Json.parseToJsonElement(String(bytes, StandardCharsets.UTF_8)) as? JsonObject }
                catch (_: Exception) { null } ?: return send(exchange, 400, "invalid_json")
            fun field(name: String): String? = (body[name] as? JsonPrimitive)?.takeIf { it.isString }?.content
            val model = field("model")?.trim()?.takeIf { it.isNotEmpty() }
                ?: return send(exchange, 400, "model_required")
            val input = field("input")?.takeIf { it.isNotBlank() && it.length <= 32_000 }
                ?: return send(exchange, 400, "input_required")
            val application = field("application")?.takeIf { it.matches(Regex("[a-zA-Z0-9_-]{1,64}")) }
                ?: return send(exchange, 400, "application_required")
            val schema = body["schema"] as? JsonObject ?: return send(exchange, 400, "schema_required")
            val schemaName = field("schemaName")?.takeIf { it.matches(Regex("[a-zA-Z0-9_-]{1,64}")) }
                ?: return send(exchange, 400, "schema_name_required")
            val result = AiUsageContextHolder.withContext(AiUsageContext(application, null)) {
                client.generate(StructuredGenerationRequest(AiProfile.LUNA, input, schemaName, schema.toString(), model = model))
            }
            when (result) {
                is Outcome.Success -> {
                    val value = result.value
                    val payload = buildJsonObject {
                        put("text", value.text)
                        value.usage?.let { usage -> put("usage", buildJsonObject {
                            usage.inputTokens?.let { put("inputTokens", it) }
                            usage.outputTokens?.let { put("outputTokens", it) }
                            usage.totalTokens?.let { put("totalTokens", it) }
                        }) }
                    }.toString()
                    respond(exchange, 200, payload)
                }
                is Outcome.Failure -> send(exchange, 502, "upstream_failure")
            }
        } catch (_: Exception) {
            send(exchange, 500, "internal_error")
        } finally {
            exchange.close()
        }
    }

    private fun send(exchange: HttpExchange, status: Int, code: String) =
        respond(exchange, status, buildJsonObject { put("error", code) }.toString())

    private fun respond(exchange: HttpExchange, status: Int, body: String) {
        val bytes = body.toByteArray(StandardCharsets.UTF_8)
        exchange.responseHeaders.set("Content-Type", "application/json; charset=utf-8")
        exchange.sendResponseHeaders(status, bytes.size.toLong())
        exchange.responseBody.use { it.write(bytes) }
    }
}
