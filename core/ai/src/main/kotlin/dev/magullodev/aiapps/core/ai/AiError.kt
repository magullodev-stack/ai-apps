package dev.magullodev.aiapps.core.ai

sealed interface AiError {
    data object InvalidSchemaJson : AiError
    data object TransportFailure : AiError
    data class TransportFailureDiagnosed(
        val kind: AiTransportFailureKind,
        val detail: String,
    ) : AiError
    data class HttpFailure(val status: Int) : AiError
    data object InvalidResponseJson : AiError
    data object MissingOutputText : AiError
}

enum class AiTransportFailureKind {
    CONNECT_TIMEOUT,
    READ_TIMEOUT,
    IO,
    INVALID_REQUEST,
}
