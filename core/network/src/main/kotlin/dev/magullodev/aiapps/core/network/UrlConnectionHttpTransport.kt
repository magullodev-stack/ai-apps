package dev.magullodev.aiapps.core.network

import dev.magullodev.aiapps.core.contracts.Outcome
import java.io.IOException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException

class UrlConnectionHttpTransport(
    private val connectTimeoutMillis: Int,
    private val readTimeoutMillis: Int,
) : HttpTransport {
    init {
        require(connectTimeoutMillis > 0)
        require(readTimeoutMillis > 0)
    }

    override fun execute(request: HttpRequest): Outcome<HttpResponse, NetworkError> {
        val uri = request.uri
        if (
            !uri.isAbsolute ||
            !(uri.scheme.equals("http", ignoreCase = true) || uri.scheme.equals("https", ignoreCase = true)) ||
            uri.host.isNullOrBlank()
        ) {
            return Outcome.Failure(NetworkError.InvalidRequest("URI must be absolute HTTP(S) with a host"))
        }
        if (request.method == HttpMethod.GET && request.body != null) {
            return Outcome.Failure(NetworkError.InvalidRequest("GET cannot have a body"))
        }

        var connection: HttpURLConnection? = null
        var phase = IoPhase.CONNECT_OR_SEND
        try {
            connection = uri.toURL().openConnection() as HttpURLConnection
            connection.connectTimeout = connectTimeoutMillis
            connection.readTimeout = readTimeoutMillis
            connection.requestMethod = request.method.name
            request.headers.forEach { (name, value) -> connection.setRequestProperty(name, value) }

            request.body?.let { body ->
                connection.doOutput = true
                connection.outputStream.use { stream ->
                    stream.write(body.toByteArray(Charsets.UTF_8))
                }
            }

            phase = IoPhase.RECEIVE
            val status = connection.responseCode
            val headers = connection.headerFields
                .filterKeys { it != null }
                .mapKeys { (name, _) -> name!! }
            val stream = if (status >= 400) connection.errorStream else connection.inputStream
            val body = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""

            return Outcome.Success(HttpResponse(status, headers, body))
        } catch (cause: SocketTimeoutException) {
            val kind = when (phase) {
                IoPhase.CONNECT_OR_SEND -> NetworkTransportFailureKind.CONNECT_TIMEOUT
                IoPhase.RECEIVE -> NetworkTransportFailureKind.READ_TIMEOUT
            }
            return Outcome.Failure(NetworkError.TransportFailure(cause, kind))
        } catch (cause: IOException) {
            return Outcome.Failure(NetworkError.TransportFailure(cause, NetworkTransportFailureKind.IO))
        } catch (cause: IllegalArgumentException) {
            return Outcome.Failure(NetworkError.InvalidRequest(cause.message ?: "Invalid HTTP request"))
        } finally {
            connection?.disconnect()
        }
    }

    private enum class IoPhase {
        CONNECT_OR_SEND,
        RECEIVE,
    }
}
