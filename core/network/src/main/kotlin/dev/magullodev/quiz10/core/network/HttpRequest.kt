package dev.magullodev.quiz10.core.network

import java.net.URI

data class HttpRequest(
    val method: HttpMethod,
    val uri: URI,
    val headers: Map<String, String> = emptyMap(),
    val body: String? = null,
)
