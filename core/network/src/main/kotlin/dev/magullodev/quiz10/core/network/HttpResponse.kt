package dev.magullodev.quiz10.core.network

data class HttpResponse(
    val status: Int,
    val headers: Map<String, List<String>>,
    val body: String,
)
