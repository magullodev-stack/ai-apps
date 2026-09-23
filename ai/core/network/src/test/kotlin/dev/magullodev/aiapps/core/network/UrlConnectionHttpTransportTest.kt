package dev.magullodev.aiapps.core.network

import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import dev.magullodev.aiapps.core.contracts.Outcome
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.URI
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.test.assertIs

class UrlConnectionHttpTransportTest {
    private val transport = UrlConnectionHttpTransport(1_000, 1_000)

    private fun withServer(handler: (HttpExchange) -> Unit, test: (URI) -> Unit) {
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { exchange -> handler(exchange) }
        server.start()
        try {
            test(URI("http://127.0.0.1:${server.address.port}/"))
        } finally {
            server.stop(0)
        }
    }

    private fun respond(exchange: HttpExchange, status: Int, body: String) {
        val bytes = body.toByteArray(Charsets.UTF_8)
        exchange.sendResponseHeaders(status, bytes.size.toLong())
        exchange.responseBody.use { it.write(bytes) }
    }

    @Test
    fun getReturnsStatusHeadersAndBody() = withServer(
        handler = { exchange ->
            exchange.responseHeaders.add("X-Result", "ok")
            respond(exchange, 200, "hello")
        },
    ) { uri ->
        val result = transport.execute(HttpRequest(HttpMethod.GET, uri))

        val response = assertIs<Outcome.Success<HttpResponse>>(result).value
        assertEquals(200, response.status)
        assertEquals("hello", response.body)
        assertEquals("ok", response.headers.entries.single { it.key.equals("X-Result", true) }.value.single())
    }

    @Test
    fun postSendsBodyAndHeaders() = withServer(
        handler = { exchange ->
            val body = exchange.requestBody.bufferedReader(Charsets.UTF_8).use { it.readText() }
            val header = exchange.requestHeaders.getFirst("X-Request")
            respond(exchange, 201, "${exchange.requestMethod}:$body:$header")
        },
    ) { uri ->
        val request = HttpRequest(
            HttpMethod.POST,
            uri,
            headers = mapOf("X-Request" to "sample"),
            body = "payload",
        )

        val response = assertIs<Outcome.Success<HttpResponse>>(transport.execute(request)).value
        assertEquals(201, response.status)
        assertEquals("POST:payload:sample", response.body)
    }

    @Test
    fun httpErrorRemainsAResponse() = withServer(
        handler = { exchange ->
            val status = if (exchange.requestURI.path == "/server-error") 503 else 422
            respond(exchange, status, "rejected")
        },
    ) { uri ->
        for ((path, expectedStatus) in listOf("" to 422, "server-error" to 503)) {
            val response = assertIs<Outcome.Success<HttpResponse>>(
                transport.execute(HttpRequest(HttpMethod.GET, uri.resolve(path))),
            ).value

            assertEquals(expectedStatus, response.status)
            assertEquals("rejected", response.body)
        }
    }

    @Test
    fun rejectsInvalidUris() {
        for (uri in listOf(URI("/relative"), URI("ftp://example.com"), URI("http:/missing-host"))) {
            val result = transport.execute(HttpRequest(HttpMethod.GET, uri))
            assertIs<NetworkError.InvalidRequest>(assertIs<Outcome.Failure<NetworkError>>(result).error)
        }
    }

    @Test
    fun connectionFailureIsATransportError() {
        val port = ServerSocket(0).use { it.localPort }
        val request = HttpRequest(HttpMethod.GET, URI("http://127.0.0.1:$port/"))

        val result = transport.execute(request)

        val error = assertIs<NetworkError.TransportFailure>(assertIs<Outcome.Failure<NetworkError>>(result).error)
        assertTrue(error.kind != NetworkTransportFailureKind.READ_TIMEOUT)
    }

    @Test
    fun slowResponseReadIsClassifiedAsReadTimeout() = withServer(
        handler = { exchange ->
            Thread.sleep(1_500)
            respond(exchange, 200, "late")
        },
    ) { uri ->
        val timeoutTransport = UrlConnectionHttpTransport(1_000, 200)
        val result = timeoutTransport.execute(HttpRequest(HttpMethod.GET, uri))

        val error = assertIs<NetworkError.TransportFailure>(assertIs<Outcome.Failure<NetworkError>>(result).error)
        assertEquals(NetworkTransportFailureKind.READ_TIMEOUT, error.kind)
    }
}
