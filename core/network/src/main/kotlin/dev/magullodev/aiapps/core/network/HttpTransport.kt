package dev.magullodev.aiapps.core.network

import dev.magullodev.aiapps.core.contracts.Outcome

fun interface HttpTransport {
    fun execute(request: HttpRequest): Outcome<HttpResponse, NetworkError>
}
