package dev.magullodev.aiapps.core.network

import java.io.IOException

sealed interface NetworkError {
    data class InvalidRequest(val reason: String) : NetworkError
    data class TransportFailure(val cause: IOException) : NetworkError
}
