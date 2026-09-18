package dev.magullodev.quiz10.apps.quiz10.web

import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.interaction.Quiz10InteractionContext
import dev.magullodev.quiz10.systems.quiz10.interaction.Quiz10InteractionError
import dev.magullodev.quiz10.systems.quiz10.interaction.Quiz10InteractionEvent
import dev.magullodev.quiz10.systems.quiz10.interaction.Quiz10InteractionMessage
import dev.magullodev.quiz10.systems.quiz10.navigation.Quiz10NavigationMenu
import dev.magullodev.quiz10.systems.quiz10.navigation.Quiz10NavigationOption
import dev.magullodev.quiz10.systems.quiz10.preparation.PreparedQuiz
import dev.magullodev.quiz10.systems.quiz10.preparation.QuizPreparationError
import dev.magullodev.quiz10.systems.quiz10.progress.PlayerProgress
import dev.magullodev.quiz10.systems.quiz10.session.Quiz10Flow
import dev.magullodev.quiz10.systems.quiz10.session.Quiz10FlowState
import dev.magullodev.quiz10.ui.web.Quiz10WebRenderer
import java.net.InetSocketAddress
import java.nio.charset.StandardCharsets
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class Quiz10WebServer(
    private val prepareQuiz: (String) -> Outcome<PreparedQuiz, QuizPreparationError>,
    private val presentInteraction: (Quiz10InteractionContext) -> Outcome<Quiz10InteractionMessage, Quiz10InteractionError> = {
        Outcome.Failure(Quiz10InteractionError.InvalidGeneratedMessage)
    },
    private val renderer: Quiz10WebRenderer = Quiz10WebRenderer(),
    host: String = "0.0.0.0",
    port: Int = 8080,
) : AutoCloseable {
    private data class InteractionSnapshot(
        val revision: Long,
        val context: Quiz10InteractionContext,
    )

    private data class WebSession(
        val lock: Any = Any(),
        var playerProgress: PlayerProgress,
        var currentTopic: String,
        var activeFlow: Quiz10Flow,
        var lastFinished: Quiz10FlowState.Finished? = null,
        var interactionSnapshot: InteractionSnapshot,
    )

    private val sessions = ConcurrentHashMap<String, WebSession>()
    private val server = HttpServer.create(InetSocketAddress(host, port), 0)

    init {
        server.createContext("/") { exchange ->
            try {
                handle(exchange)
            } catch (_: IllegalArgumentException) {
                respond(exchange, 400, renderer.renderBadRequest("Solicitud inválida.", "/"))
            } catch (_: IllegalStateException) {
                respond(exchange, 400, renderer.renderBadRequest("Acción inválida para el estado actual.", "/"))
            } catch (_: Exception) {
                respond(exchange, 500, renderer.renderPreparationError())
            }
        }
    }

    fun start(): Int {
        server.start()
        return server.address.port
    }

    override fun close() {
        server.stop(0)
    }

    private fun handle(exchange: HttpExchange) {
        val method = exchange.requestMethod
        val path = exchange.requestURI.path
        when {
            method == "GET" && path == "/" -> respond(exchange, 200, renderer.renderHome())
            method == "POST" && path == "/games" -> handleCreateGame(exchange)
            method == "POST" && path.matches(Regex("^/games/[^/]+/answer$")) -> handleAnswer(exchange)
            method == "POST" && path.matches(Regex("^/games/[^/]+/navigation$")) -> handleNavigation(exchange)
            method == "POST" && path.matches(Regex("^/games/[^/]+/topic$")) -> handleTopicChange(exchange)
            method == "GET" && path.matches(Regex("^/games/[^/]+/panel$")) -> handlePanel(exchange)
            method == "GET" && path.matches(Regex("^/games/[^/]+/interaction$")) -> handleInteraction(exchange)
            else -> respond(exchange, 404, renderer.renderNotFound())
        }
    }

    private fun handleCreateGame(exchange: HttpExchange) {
        val form = parseForm(exchange)
        val name = form["name"]?.trim().orEmpty()
        val topic = form["topic"]?.trim().orEmpty()

        if (name.isEmpty() || topic.isEmpty()) {
            respond(exchange, 400, renderer.renderBadRequest("Nombre y tema son obligatorios.", "/"))
            return
        }

        val progress = try {
            PlayerProgress.start(name)
        } catch (_: IllegalArgumentException) {
            respond(exchange, 400, renderer.renderBadRequest("Nombre inválido.", "/"))
            return
        }

        val prepared = when (val result = prepareQuiz(topic)) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> {
                respond(exchange, 500, renderer.renderPreparationError())
                return
            }
        }

        val flow = Quiz10Flow(prepared)
        val question = flow.start()
        val sessionId = UUID.randomUUID().toString()
        sessions[sessionId] = WebSession(
            playerProgress = progress,
            currentTopic = topic,
            activeFlow = flow,
            interactionSnapshot = InteractionSnapshot(
                revision = 1,
                context = Quiz10InteractionContext(
                    event = Quiz10InteractionEvent.WELCOME,
                    playerName = progress.playerName,
                    topic = topic,
                    answeredQuestions = 0,
                    correctAnswers = 0,
                    totalQuestions = 10,
                    stars = progress.stars,
                    lastAnswerCorrect = null,
                    starEarned = false,
                ),
            ),
        )

        respond(
            exchange,
            200,
            renderer.renderQuestion(sessionId, progress.playerName, topic, question, interactionRevision = 1),
        )
    }

    private fun handleAnswer(exchange: HttpExchange) {
        val sessionId = exchange.requestURI.path.split("/")[2]
        val session = sessions[sessionId]
        if (session == null) {
            respond(exchange, 404, renderer.renderNotFound())
            return
        }

        val form = parseForm(exchange)
        val selected = form["option"]?.trim()?.toIntOrNull()
        if (selected == null || selected !in 0..3) {
            respond(exchange, 400, renderer.renderBadRequest("Opción de respuesta inválida.", "/games/$sessionId/panel"))
            return
        }

        synchronized(session.lock) {
            val questionState = session.activeFlow.state as? Quiz10FlowState.Question
            if (questionState == null) {
                respond(exchange, 400, renderer.renderBadRequest("No hay una pregunta activa.", "/games/$sessionId/panel"))
                return
            }

            val answered = session.activeFlow.answer(selected)
            val advanced = (session.activeFlow.advance() as Outcome.Success).value
            when (advanced) {
                is Quiz10FlowState.Question -> {
                    val nextRevision = updateInteractionSnapshot(
                        session = session,
                        context = Quiz10InteractionContext(
                            event = Quiz10InteractionEvent.AFTER_ANSWER,
                            playerName = session.playerProgress.playerName,
                            topic = session.currentTopic,
                            answeredQuestions = answered.answeredQuestions,
                            correctAnswers = answered.correctAnswers,
                            totalQuestions = answered.totalQuestions,
                            stars = session.playerProgress.stars,
                            lastAnswerCorrect = answered.isCorrect,
                            starEarned = false,
                        ),
                    )
                    respond(
                        exchange,
                        200,
                        renderer.renderQuestion(
                            sessionId = sessionId,
                            playerName = session.playerProgress.playerName,
                            topic = session.currentTopic,
                            state = advanced,
                            interactionRevision = nextRevision,
                            correction = Quiz10WebRenderer.Correction(
                                isCorrect = answered.isCorrect,
                                correctAnswer = answered.question.options[answered.question.correctOptionIndex],
                                selectedFeedback = answered.question.feedbackFor(selected),
                            ),
                        ),
                    )
                }
                is Quiz10FlowState.Finished -> {
                    session.playerProgress = session.playerProgress.recordQuiz(advanced.correctAnswers)
                    session.lastFinished = advanced
                    val nextRevision = updateInteractionSnapshot(
                        session = session,
                        context = Quiz10InteractionContext(
                            event = Quiz10InteractionEvent.FINISH,
                            playerName = session.playerProgress.playerName,
                            topic = session.currentTopic,
                            answeredQuestions = 10,
                            correctAnswers = advanced.correctAnswers,
                            totalQuestions = advanced.totalQuestions,
                            stars = session.playerProgress.stars,
                            lastAnswerCorrect = answered.isCorrect,
                            starEarned = advanced.correctAnswers == 10,
                        ),
                    )
                    val menu = Quiz10NavigationMenu.forTopic(session.currentTopic)
                    respond(
                        exchange,
                        200,
                        renderer.renderFinished(sessionId, session.playerProgress, advanced, menu, interactionRevision = nextRevision),
                    )
                }
                else -> {
                    respond(exchange, 400, renderer.renderBadRequest("Estado de partida inválido.", "/games/$sessionId/panel"))
                }
            }
        }
    }

    private fun handleNavigation(exchange: HttpExchange) {
        val sessionId = exchange.requestURI.path.split("/")[2]
        val session = sessions[sessionId]
        if (session == null) {
            respond(exchange, 404, renderer.renderNotFound())
            return
        }

        val form = parseForm(exchange)
        val selection = form["selection"]?.trim()?.toIntOrNull()
        if (selection == null) {
            respond(exchange, 400, renderer.renderBadRequest("Selección inválida.", "/games/$sessionId/panel"))
            return
        }

        synchronized(session.lock) {
            val lastFinished = session.lastFinished
            if (lastFinished == null) {
                respond(exchange, 400, renderer.renderBadRequest("No hay partida finalizada todavía.", "/"))
                return
            }

            val menu = Quiz10NavigationMenu.forTopic(session.currentTopic)
            val option = try {
                menu.select(selection)
            } catch (_: IllegalArgumentException) {
                respond(exchange, 400, renderer.renderBadRequest("Selección inválida.", "/games/$sessionId/panel"))
                return
            }

            when (option) {
                Quiz10NavigationOption.ANOTHER_QUIZ_SAME_TOPIC -> {
                    val prepared = when (val result = prepareQuiz(session.currentTopic)) {
                        is Outcome.Success -> result.value
                        is Outcome.Failure -> {
                            respond(exchange, 500, renderer.renderPreparationError())
                            return
                        }
                    }
                    val flow = Quiz10Flow(prepared)
                    session.activeFlow = flow
                    val question = flow.start()
                    val nextRevision = updateInteractionSnapshot(
                        session = session,
                        context = Quiz10InteractionContext(
                            event = Quiz10InteractionEvent.WELCOME,
                            playerName = session.playerProgress.playerName,
                            topic = session.currentTopic,
                            answeredQuestions = 0,
                            correctAnswers = 0,
                            totalQuestions = 10,
                            stars = session.playerProgress.stars,
                            lastAnswerCorrect = null,
                            starEarned = false,
                        ),
                    )
                    respond(
                        exchange,
                        200,
                        renderer.renderQuestion(
                            sessionId,
                            session.playerProgress.playerName,
                            session.currentTopic,
                            question,
                            interactionRevision = nextRevision,
                        ),
                    )
                }

                Quiz10NavigationOption.CHOOSE_ANOTHER_TOPIC -> {
                    respond(
                        exchange,
                        200,
                        renderer.renderChooseTopic(sessionId, session.playerProgress.playerName, session.currentTopic),
                    )
                }

                Quiz10NavigationOption.REVIEW_WRONG_ANSWERS -> {
                    respond(exchange, 200, renderer.renderFailedAnswers(sessionId, lastFinished))
                }

                Quiz10NavigationOption.RANDOM_QUIZ,
                Quiz10NavigationOption.VIEW_SOURCES,
                Quiz10NavigationOption.CREATE_IMAGE_QUIZ -> {
                    respond(exchange, 200, renderer.renderUnavailable(sessionId))
                }
            }
        }
    }

    private fun handleTopicChange(exchange: HttpExchange) {
        val sessionId = exchange.requestURI.path.split("/")[2]
        val session = sessions[sessionId]
        if (session == null) {
            respond(exchange, 404, renderer.renderNotFound())
            return
        }

        val form = parseForm(exchange)
        val topic = form["topic"]?.trim().orEmpty()
        if (topic.isEmpty()) {
            respond(exchange, 400, renderer.renderBadRequest("El tema no puede estar vacío.", "/games/$sessionId/panel"))
            return
        }

        synchronized(session.lock) {
            val prepared = when (val result = prepareQuiz(topic)) {
                is Outcome.Success -> result.value
                is Outcome.Failure -> {
                    respond(exchange, 500, renderer.renderPreparationError())
                    return
                }
            }

            session.currentTopic = topic
            val flow = Quiz10Flow(prepared)
            session.activeFlow = flow
            val question = flow.start()
            val nextRevision = updateInteractionSnapshot(
                session = session,
                context = Quiz10InteractionContext(
                    event = Quiz10InteractionEvent.WELCOME,
                    playerName = session.playerProgress.playerName,
                    topic = session.currentTopic,
                    answeredQuestions = 0,
                    correctAnswers = 0,
                    totalQuestions = 10,
                    stars = session.playerProgress.stars,
                    lastAnswerCorrect = null,
                    starEarned = false,
                ),
            )
            respond(
                exchange,
                200,
                renderer.renderQuestion(
                    sessionId,
                    session.playerProgress.playerName,
                    session.currentTopic,
                    question,
                    interactionRevision = nextRevision,
                ),
            )
        }
    }

    private fun handlePanel(exchange: HttpExchange) {
        val sessionId = exchange.requestURI.path.split("/")[2]
        val session = sessions[sessionId]
        if (session == null) {
            respond(exchange, 404, renderer.renderNotFound())
            return
        }

        synchronized(session.lock) {
            val finished = session.lastFinished
            if (finished == null) {
                respond(exchange, 400, renderer.renderBadRequest("No hay partida finalizada todavía.", "/"))
                return
            }
            val menu = Quiz10NavigationMenu.forTopic(session.currentTopic)
            respond(
                exchange,
                200,
                renderer.renderFinished(
                    sessionId,
                    session.playerProgress,
                    finished,
                    menu,
                    interactionRevision = session.interactionSnapshot.revision,
                ),
            )
        }
    }

    private fun handleInteraction(exchange: HttpExchange) {
        val sessionId = exchange.requestURI.path.split("/")[2]
        val session = sessions[sessionId]
        if (session == null) {
            respondText(exchange, 404, "Sesión no encontrada")
            return
        }

        val requestedRevision = parseRevision(exchange.requestURI.query)
        if (requestedRevision == null) {
            respondText(exchange, 400, "revision inválida")
            return
        }

        val snapshot = synchronized(session.lock) {
            val current = session.interactionSnapshot
            if (current.revision != requestedRevision) null else current
        }

        if (snapshot == null) {
            respondText(exchange, 409, "revision obsoleta")
            return
        }

        when (val result = presentInteraction(snapshot.context)) {
            is Outcome.Success -> respondText(exchange, 200, result.value.message)
            is Outcome.Failure -> respondText(exchange, 503, "")
        }
    }

    private fun parseForm(exchange: HttpExchange): Map<String, String> {
        val body = exchange.requestBody.readAllBytes().toString(StandardCharsets.UTF_8)
        if (body.isBlank()) return emptyMap()
        return body.split("&")
            .mapNotNull { pair ->
                val parts = pair.split("=", limit = 2)
                val key = parts.getOrNull(0) ?: return@mapNotNull null
                val rawValue = parts.getOrNull(1).orEmpty()
                urlDecode(key) to urlDecode(rawValue)
            }
            .toMap()
    }

    private fun urlDecode(text: String): String = java.net.URLDecoder.decode(text, StandardCharsets.UTF_8)

    private fun parseRevision(query: String?): Long? {
        if (query.isNullOrBlank()) return null
        val entries = query.split("&")
            .mapNotNull {
                val parts = it.split("=", limit = 2)
                val key = parts.getOrNull(0) ?: return@mapNotNull null
                val value = parts.getOrNull(1).orEmpty()
                urlDecode(key) to urlDecode(value)
            }
            .toMap()

        val value = entries["revision"] ?: return null
        return value.toLongOrNull()?.takeIf { it > 0 }
    }

    private fun updateInteractionSnapshot(session: WebSession, context: Quiz10InteractionContext): Long {
        val nextRevision = session.interactionSnapshot.revision + 1
        session.interactionSnapshot = InteractionSnapshot(nextRevision, context)
        return nextRevision
    }

    private fun respond(exchange: HttpExchange, status: Int, html: String) {
        val bytes = html.toByteArray(StandardCharsets.UTF_8)
        exchange.responseHeaders.add("Content-Type", "text/html; charset=utf-8")
        exchange.sendResponseHeaders(status, bytes.size.toLong())
        exchange.responseBody.use { it.write(bytes) }
    }

    private fun respondText(exchange: HttpExchange, status: Int, text: String) {
        val bytes = text.toByteArray(StandardCharsets.UTF_8)
        exchange.responseHeaders.add("Content-Type", "text/plain; charset=utf-8")
        exchange.sendResponseHeaders(status, bytes.size.toLong())
        exchange.responseBody.use { it.write(bytes) }
    }
}
