package dev.magullodev.aiapps.core.network

data class HttpResponse(
    val status: Int,
    val headers: Map<String, List<String>>,
    val body: String,
)
