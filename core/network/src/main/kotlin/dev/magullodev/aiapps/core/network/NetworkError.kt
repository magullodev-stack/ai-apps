package dev.magullodev.aiapps.core.network

import java.io.IOException

sealed interface NetworkError {
    data class InvalidRequest(val reason: String) : NetworkError
    data class TransportFailure(
        val cause: IOException,
        val kind: NetworkTransportFailureKind = NetworkTransportFailureKind.IO,
    ) : NetworkError
}

enum class NetworkTransportFailureKind {
    CONNECT_TIMEOUT,
    READ_TIMEOUT,
    IO,
}
