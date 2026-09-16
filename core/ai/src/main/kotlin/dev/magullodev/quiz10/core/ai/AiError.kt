package dev.magullodev.quiz10.core.ai

sealed interface AiError {
    data object InvalidSchemaJson : AiError
    data object TransportFailure : AiError
    data class HttpFailure(val status: Int) : AiError
    data object InvalidResponseJson : AiError
    data object MissingOutputText : AiError
}
