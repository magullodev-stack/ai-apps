package dev.magullodev.quiz10.core.network

import dev.magullodev.quiz10.core.contracts.Outcome

fun interface HttpTransport {
    fun execute(request: HttpRequest): Outcome<HttpResponse, NetworkError>
}
