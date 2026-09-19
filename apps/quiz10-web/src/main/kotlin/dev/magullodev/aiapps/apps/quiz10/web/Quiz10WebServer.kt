package dev.magullodev.aiapps.apps.quiz10.web

import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import dev.magullodev.aiapps.core.ai.AiError
import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.aiapps.systems.games.quiz10.coverage.Quiz10Area
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlan
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlanner
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRouteItem
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.CoverageQuestionReviewError
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.CoverageRouteGenerationError
import dev.magullodev.aiapps.systems.games.quiz10.coverage.terra.CoverageRouteValidationError
import dev.magullodev.aiapps.systems.games.quiz10.interaction.Quiz10InteractionContext
import dev.magullodev.aiapps.systems.games.quiz10.interaction.Quiz10InteractionError
import dev.magullodev.aiapps.systems.games.quiz10.interaction.Quiz10InteractionEvent
import dev.magullodev.aiapps.systems.games.quiz10.interaction.Quiz10InteractionMessage
import dev.magullodev.aiapps.systems.games.quiz10.navigation.Quiz10NavigationMenu
import dev.magullodev.aiapps.systems.games.quiz10.navigation.Quiz10NavigationOption
import dev.magullodev.aiapps.systems.games.quiz10.preparation.CoverageQuestionCompletionError
import dev.magullodev.aiapps.systems.games.quiz10.preparation.PreparedQuiz
import dev.magullodev.aiapps.systems.games.quiz10.preparation.QuizPreparationError
import dev.magullodev.aiapps.systems.games.quiz10.preparation.luna.QuizTurnGenerationError
import dev.magullodev.aiapps.systems.games.quiz10.question.QuizQuestion
import dev.magullodev.aiapps.systems.games.quiz10.session.Quiz10FlowTransitionError
import dev.magullodev.aiapps.systems.games.quiz10.progress.PlayerProgress
import dev.magullodev.aiapps.systems.games.quiz10.session.Quiz10Flow
import dev.magullodev.aiapps.systems.games.quiz10.session.Quiz10FlowState
import dev.magullodev.aiapps.ui.quiz10.web.Quiz10WebRenderer
import java.net.InetSocketAddress
import java.nio.charset.StandardCharsets
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class Quiz10WebServer(
    private val prepareQuiz: (StandardCoveragePlan) -> Outcome<PreparedQuiz, QuizPreparationError>,
    private val generateTurn: (CoverageRouteItem, Int) -> Outcome<QuizQuestion, QuizTurnGenerationError>,
    private val presentInteraction: (Quiz10InteractionContext) -> Outcome<Quiz10InteractionMessage, Quiz10InteractionError> = {
        Outcome.Failure(Quiz10InteractionError.InvalidGeneratedMessage)
    },
    private val renderer: Quiz10WebRenderer = Quiz10WebRenderer(),
    private val planner: StandardCoveragePlanner = StandardCoveragePlanner(),
    host: String = "0.0.0.0",
    port: Int = 8080,
) : AutoCloseable {
    private sealed interface SelectionMode {
        data object Random : SelectionMode
        data class Area(val area: Quiz10Area) : SelectionMode
    }

    private data class InteractionSnapshot(
        val revision: Long,
        val context: Quiz10InteractionContext,
    )

    private data class WebSession(
        val lock: Any = Any(),
        var playerProgress: PlayerProgress,
        var currentSelection: SelectionMode,
        var currentTopic: String,
        var activeFlow: Quiz10Flow,
        var lastFinished: Quiz10FlowState.Finished? = null,
        var interactionSnapshot: InteractionSnapshot,
    )

    private val sessions = ConcurrentHashMap<String, WebSession>()
    private val server = HttpServer.create(InetSocketAddress(host, port), 0)
    private val executor: ExecutorService = Executors.newVirtualThreadPerTaskExecutor()

    init {
        server.executor = executor
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
        executor.shutdown()
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
        val selectionRaw = form["selection"]?.trim().orEmpty()

        if (name.isEmpty() || selectionRaw.isEmpty()) {
            respond(exchange, 400, renderer.renderBadRequest("Nombre y modalidad/área son obligatorios.", "/"))
            return
        }

        val selection = parseSelectionMode(selectionRaw)
        if (selection == null) {
            respond(exchange, 400, renderer.renderBadRequest("Selección de área desconocida.", "/"))
            return
        }

        val progress = try {
            PlayerProgress.start(name)
        } catch (_: IllegalArgumentException) {
            respond(exchange, 400, renderer.renderBadRequest("Nombre inválido.", "/"))
            return
        }

        val prepared = when (val result = prepareQuiz(buildPlan(selection))) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> {
                logPreparationFailure(result.error)
                respond(
                    exchange,
                    preparationErrorStatus(result.error),
                    renderer.renderPreparationError(preparationErrorMessage(result.error)),
                )
                return
            }
        }

        val flow = Quiz10Flow(prepared, generateTurn)
        val question = when (val result = flow.start()) {
            is Outcome.Success -> result.value
            is Outcome.Failure -> {
                logTurnFailure(result.error)
                respond(exchange, 500, renderer.renderPreparationError(turnErrorMessage(result.error)))
                return
            }
        }
        val sessionId = UUID.randomUUID().toString()
        sessions[sessionId] = WebSession(
            playerProgress = progress,
            currentSelection = selection,
            currentTopic = topicForSelection(selection),
            activeFlow = flow,
            interactionSnapshot = InteractionSnapshot(
                revision = 1,
                context = Quiz10InteractionContext(
                    event = Quiz10InteractionEvent.WELCOME,
                    playerName = progress.playerName,
                    topic = topicForSelection(selection),
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
            renderer.renderQuestion(sessionId, progress.playerName, topicForSelection(selection), question, interactionRevision = 1),
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
            val advanced = when (val result = session.activeFlow.advance()) {
                is Outcome.Success -> result.value
                is Outcome.Failure -> {
                    logTurnFailure(result.error)
                    respond(exchange, 500, renderer.renderPreparationError(turnErrorMessage(result.error)))
                    return
                }
            }
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
                    val prepared = when (val result = prepareQuiz(buildPlan(session.currentSelection))) {
                        is Outcome.Success -> result.value
                        is Outcome.Failure -> {
                            logPreparationFailure(result.error)
                            respond(
                                exchange,
                                preparationErrorStatus(result.error),
                                renderer.renderPreparationError(
                                    message = preparationErrorMessage(result.error),
                                    backPath = "/games/$sessionId/panel",
                                ),
                            )
                            return
                        }
                    }
                    val flow = Quiz10Flow(prepared, generateTurn)
                    val question = when (val result = flow.start()) {
                        is Outcome.Success -> result.value
                        is Outcome.Failure -> {
                            logTurnFailure(result.error)
                            respond(
                                exchange,
                                500,
                                renderer.renderPreparationError(
                                    message = turnErrorMessage(result.error),
                                    backPath = "/games/$sessionId/panel",
                                ),
                            )
                            return
                        }
                    }
                    session.activeFlow = flow
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
                        renderer.renderChooseTopic(sessionId, session.playerProgress.playerName, selectionValue(session.currentSelection)),
                    )
                }

                Quiz10NavigationOption.RANDOM_QUIZ -> {
                    val selection = SelectionMode.Random
                    val prepared = when (val result = prepareQuiz(buildPlan(selection))) {
                        is Outcome.Success -> result.value
                        is Outcome.Failure -> {
                            logPreparationFailure(result.error)
                            respond(
                                exchange,
                                preparationErrorStatus(result.error),
                                renderer.renderPreparationError(
                                    message = preparationErrorMessage(result.error),
                                    backPath = "/games/$sessionId/panel",
                                ),
                            )
                            return
                        }
                    }
                    val flow = Quiz10Flow(prepared, generateTurn)
                    val question = when (val result = flow.start()) {
                        is Outcome.Success -> result.value
                        is Outcome.Failure -> {
                            logTurnFailure(result.error)
                            respond(
                                exchange,
                                500,
                                renderer.renderPreparationError(
                                    message = turnErrorMessage(result.error),
                                    backPath = "/games/$sessionId/panel",
                                ),
                            )
                            return
                        }
                    }
                    session.currentSelection = selection
                    session.currentTopic = topicForSelection(selection)
                    session.activeFlow = flow
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

                Quiz10NavigationOption.REVIEW_WRONG_ANSWERS -> {
                    respond(exchange, 200, renderer.renderFailedAnswers(sessionId, lastFinished))
                }

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
        val selectionRaw = form["selection"]?.trim().orEmpty()
        if (selectionRaw.isEmpty()) {
            respond(exchange, 400, renderer.renderBadRequest("Debes seleccionar modalidad o área.", "/games/$sessionId/panel"))
            return
        }
        val selection = parseSelectionMode(selectionRaw)
        if (selection == null) {
            respond(exchange, 400, renderer.renderBadRequest("Selección de área desconocida.", "/games/$sessionId/panel"))
            return
        }

        synchronized(session.lock) {
            val prepared = when (val result = prepareQuiz(buildPlan(selection))) {
                is Outcome.Success -> result.value
                is Outcome.Failure -> {
                    logPreparationFailure(result.error)
                    respond(
                        exchange,
                        preparationErrorStatus(result.error),
                        renderer.renderPreparationError(
                            message = preparationErrorMessage(result.error),
                            backPath = "/games/$sessionId/panel",
                        ),
                    )
                    return
                }
            }

            val flow = Quiz10Flow(prepared, generateTurn)
            val question = when (val result = flow.start()) {
                is Outcome.Success -> result.value
                is Outcome.Failure -> {
                    logTurnFailure(result.error)
                    respond(
                        exchange,
                        500,
                        renderer.renderPreparationError(
                            message = turnErrorMessage(result.error),
                            backPath = "/games/$sessionId/panel",
                        ),
                    )
                    return
                }
            }
            session.currentSelection = selection
            session.currentTopic = topicForSelection(selection)
            session.activeFlow = flow
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

    private fun logPreparationFailure(error: QuizPreparationError) {
        val cause = describePreparationCause(error)
        System.err.println("quiz10-web stage=coverage error=${describePreparationError(error)} cause=${cause}")
    }

    private fun describePreparationCause(error: QuizPreparationError): String = when (error) {
        is QuizPreparationError.CoverageRouteGenerationFailed -> describeCoverageGenerationError(error.cause)
        is QuizPreparationError.CoverageRouteValidationFailed -> describeCoverageValidationError(error.cause)
        is QuizPreparationError.StandardCoverageRouteGenerationFailed -> describeCoverageGenerationError(error.cause)
        is QuizPreparationError.CoverageQuestionReviewFailed -> describeCoverageQuestionReviewError(error.cause)
        is QuizPreparationError.CoverageQuestionCompletionFailed -> describeCoverageQuestionCompletionError(error.cause)
        is QuizPreparationError.StandardPreparationNotConfigured -> "QuizPreparationError.StandardPreparationNotConfigured"
        is QuizPreparationError.InvalidCoverageRouteSize -> "QuizPreparationError.InvalidCoverageRouteSize"
    }

    private fun preparationErrorStatus(error: QuizPreparationError): Int = when (error) {
        is QuizPreparationError.CoverageRouteValidationFailed -> when (error.cause) {
            is CoverageRouteValidationError.RouteRejected -> 422
            else -> 500
        }
        is QuizPreparationError.CoverageQuestionReviewFailed -> 502
        is QuizPreparationError.CoverageQuestionCompletionFailed -> 502
        else -> 500
    }

    private fun logTurnFailure(error: Quiz10FlowTransitionError) {
        val questionNumber = when (error) {
            is Quiz10FlowTransitionError.TurnGenerationFailed -> error.questionNumber
        }
        val cause = when (error) {
            is Quiz10FlowTransitionError.TurnGenerationFailed -> when (val turnCause = error.cause) {
                is QuizTurnGenerationError.GenerationFailed -> describeAiError(turnCause.cause)
                else -> describeTurnGenerationError(turnCause)
            }
        }
        val questionSuffix = questionNumber?.let { " question=$it" } ?: ""
        System.err.println("quiz10-web stage=turn${questionSuffix} error=${describeTurnTransitionError(error)} cause=${cause}")
    }

    private fun preparationErrorMessage(error: QuizPreparationError): String = when (error) {
        is QuizPreparationError.CoverageRouteGenerationFailed -> {
            val causeName = when (val cause = error.cause) {
                is CoverageRouteGenerationError.BlankTopic -> "BlankTopic"
                is CoverageRouteGenerationError.GenerationFailed -> "CoverageRouteGenerationFailed(${describeAiError(cause.cause)})"
                is CoverageRouteGenerationError.InvalidGeneratedRoute -> "InvalidGeneratedRoute"
            }
            "No se pudo generar la ruta de cobertura: CoverageRouteGenerationFailed($causeName)"
        }
        is QuizPreparationError.CoverageRouteValidationFailed -> when (val cause = error.cause) {
            is CoverageRouteValidationError.RouteRejected -> {
                val details = cause.issues.joinToString("; ")
                "La ruta de cobertura fue rechazada por validación semántica: $details"
            }
            is CoverageRouteValidationError.GenerationFailed -> {
                "No se pudo validar la ruta de cobertura: CoverageRouteValidationFailed(${describeAiError(cause.cause)})"
            }
            CoverageRouteValidationError.InvalidStructuredResponse -> {
                "No se pudo validar la ruta de cobertura: CoverageRouteValidationFailed(InvalidStructuredResponse)"
            }
        }

        is QuizPreparationError.StandardCoverageRouteGenerationFailed -> {
            val causeName = when (val cause = error.cause) {
                is CoverageRouteGenerationError.BlankTopic -> "BlankTopic"
                is CoverageRouteGenerationError.GenerationFailed -> "CoverageRouteGenerationFailed(${describeAiError(cause.cause)})"
                is CoverageRouteGenerationError.InvalidGeneratedRoute -> "InvalidGeneratedRoute"
            }
            "No se pudo generar la ruta de cobertura estándar: CoverageRouteGenerationFailed($causeName)"
        }

        is QuizPreparationError.CoverageQuestionReviewFailed ->
            "No se pudo validar por fila la cobertura: ${describeCoverageQuestionReviewError(error.cause)}"

        is QuizPreparationError.CoverageQuestionCompletionFailed ->
            "No se pudo completar la cobertura con reemplazos: ${describeCoverageQuestionCompletionError(error.cause)}"

        is QuizPreparationError.StandardPreparationNotConfigured ->
            "La preparación estándar no está configurada"

        is QuizPreparationError.InvalidCoverageRouteSize -> "No se pudo generar la ruta de cobertura: InvalidCoverageRouteSize(size=${error.size})"
    }

    private fun turnErrorMessage(error: Quiz10FlowTransitionError): String = when (error) {
        is Quiz10FlowTransitionError.TurnGenerationFailed -> when (val cause = error.cause) {
            is QuizTurnGenerationError.InvalidCoverageRouteItem -> "No se pudo generar la pregunta ${error.questionNumber}: TurnGenerationFailed(${describeTurnGenerationError(cause)})"
            is QuizTurnGenerationError.InvalidCorrectOptionIndex -> "No se pudo generar la pregunta ${error.questionNumber}: TurnGenerationFailed(${describeTurnGenerationError(cause)})"
            is QuizTurnGenerationError.GenerationFailed -> "No se pudo generar la pregunta ${error.questionNumber}: TurnGenerationFailed(${describeAiError(cause.cause)})"
            is QuizTurnGenerationError.InvalidGeneratedTurn -> "No se pudo generar la pregunta ${error.questionNumber}: TurnGenerationFailed(${describeTurnGenerationError(cause)})"
        }
    }

    private fun describePreparationError(error: QuizPreparationError): String = when (error) {
        is QuizPreparationError.CoverageRouteGenerationFailed -> "QuizPreparationError.CoverageRouteGenerationFailed"
        is QuizPreparationError.CoverageRouteValidationFailed -> "QuizPreparationError.CoverageRouteValidationFailed"
        is QuizPreparationError.StandardCoverageRouteGenerationFailed -> "QuizPreparationError.StandardCoverageRouteGenerationFailed"
        is QuizPreparationError.CoverageQuestionReviewFailed -> "QuizPreparationError.CoverageQuestionReviewFailed"
        is QuizPreparationError.CoverageQuestionCompletionFailed -> "QuizPreparationError.CoverageQuestionCompletionFailed"
        is QuizPreparationError.StandardPreparationNotConfigured -> "QuizPreparationError.StandardPreparationNotConfigured"
        is QuizPreparationError.InvalidCoverageRouteSize -> "QuizPreparationError.InvalidCoverageRouteSize"
    }

    private fun describeTurnTransitionError(error: Quiz10FlowTransitionError): String = when (error) {
        is Quiz10FlowTransitionError.TurnGenerationFailed -> "Quiz10FlowTransitionError.TurnGenerationFailed"
    }

    private fun describeCoverageGenerationError(error: CoverageRouteGenerationError): String = when (error) {
        is CoverageRouteGenerationError.BlankTopic -> "CoverageRouteGenerationError.BlankTopic"
        is CoverageRouteGenerationError.GenerationFailed -> "CoverageRouteGenerationError.GenerationFailed"
        is CoverageRouteGenerationError.InvalidGeneratedRoute -> "CoverageRouteGenerationError.InvalidGeneratedRoute"
    }

    private fun describeCoverageValidationError(error: CoverageRouteValidationError): String = when (error) {
        is CoverageRouteValidationError.GenerationFailed -> "CoverageRouteValidationError.GenerationFailed"
        CoverageRouteValidationError.InvalidStructuredResponse -> "CoverageRouteValidationError.InvalidStructuredResponse"
        is CoverageRouteValidationError.RouteRejected -> "CoverageRouteValidationError.RouteRejected"
    }

    private fun describeCoverageQuestionReviewError(error: CoverageQuestionReviewError): String = when (error) {
        is CoverageQuestionReviewError.GenerationFailed -> "CoverageQuestionReviewError.GenerationFailed(cause=${describeAiError(error.cause)})"
        CoverageQuestionReviewError.InvalidStructuredResponse -> "CoverageQuestionReviewError.InvalidStructuredResponse"
    }

    private fun describeCoverageQuestionCompletionError(error: CoverageQuestionCompletionError): String = when (error) {
        is CoverageQuestionCompletionError.InputMismatch ->
            "CoverageQuestionCompletionError.InputMismatch(detail=${error.detail})"

        is CoverageQuestionCompletionError.ReplacementGenerationFailed ->
            "CoverageQuestionCompletionError.ReplacementGenerationFailed(cause=${error.cause})"

        is CoverageQuestionCompletionError.ExhaustedReplacementAttempts ->
            "CoverageQuestionCompletionError.ExhaustedReplacementAttempts(pendingPositions=${error.pendingPositions})"
    }

    private fun parseSelectionMode(selectionRaw: String): SelectionMode? {
        if (selectionRaw == Quiz10WebRenderer.RANDOM_SELECTION_VALUE) {
            return SelectionMode.Random
        }
        val area = Quiz10Area.fromLabel(selectionRaw) ?: return null
        return SelectionMode.Area(area)
    }

    private fun buildPlan(selection: SelectionMode): StandardCoveragePlan = when (selection) {
        SelectionMode.Random -> planner.random()
        is SelectionMode.Area -> planner.forArea(selection.area)
    }

    private fun selectionValue(selection: SelectionMode): String = when (selection) {
        SelectionMode.Random -> Quiz10WebRenderer.RANDOM_SELECTION_VALUE
        is SelectionMode.Area -> selection.area.label
    }

    private fun topicForSelection(selection: SelectionMode): String = when (selection) {
        SelectionMode.Random -> "Aleatorio"
        is SelectionMode.Area -> selection.area.label
    }

    private fun describeTurnGenerationError(error: QuizTurnGenerationError): String = when (error) {
        is QuizTurnGenerationError.InvalidCoverageRouteItem -> "QuizTurnGenerationError.InvalidCoverageRouteItem"
        is QuizTurnGenerationError.InvalidCorrectOptionIndex -> "QuizTurnGenerationError.InvalidCorrectOptionIndex"
        is QuizTurnGenerationError.GenerationFailed -> "QuizTurnGenerationError.GenerationFailed"
        is QuizTurnGenerationError.InvalidGeneratedTurn -> "QuizTurnGenerationError.InvalidGeneratedTurn"
    }

    private fun describeAiError(error: AiError): String = when (error) {
        AiError.InvalidSchemaJson -> "AiError.InvalidSchemaJson"
        AiError.TransportFailure -> "AiError.TransportFailure"
        is AiError.HttpFailure -> "AiError.HttpFailure(${error.status})"
        AiError.InvalidResponseJson -> "AiError.InvalidResponseJson"
        AiError.MissingOutputText -> "AiError.MissingOutputText"
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
