package dev.magullodev.aiapps.ui.quiz10.web

import dev.magullodev.aiapps.systems.games.quiz10.coverage.Quiz10Area
import dev.magullodev.aiapps.systems.games.quiz10.navigation.Quiz10NavigationMenu
import dev.magullodev.aiapps.systems.games.quiz10.navigation.Quiz10NavigationOption
import dev.magullodev.aiapps.systems.games.quiz10.progress.PlayerProgress
import dev.magullodev.aiapps.systems.games.quiz10.result.QuizAnswerRecord
import dev.magullodev.aiapps.systems.games.quiz10.session.Quiz10FlowState

class Quiz10WebRenderer {
    companion object {
        const val RANDOM_SELECTION_VALUE: String = "__RANDOM__"
    }

    data class Correction(
        val isCorrect: Boolean,
        val correctAnswer: String,
        val selectedFeedback: String,
    )

    fun renderHome(errorMessage: String? = null): String = page("Quiz10 Web") {
        appendLine("<h1>Quiz10</h1>")
        if (!errorMessage.isNullOrBlank()) {
            appendLine("<p class=\"error\">${escapeHtml(errorMessage)}</p>")
        }
        appendLine("<form method=\"post\" action=\"/games\" id=\"start-form\">")
        appendLine("<label>Nombre <input name=\"name\" required></label>")
        appendLine("<label>Modalidad / Área")
        appendLine("<select name=\"selection\" required>")
        appendLine(selectionOptionsHtml())
        appendLine("</select>")
        appendLine("</label>")
        appendLine("<button type=\"submit\">Empezar Quiz10</button>")
        appendLine("<p id=\"preparing\" style=\"display:none\">Preparando Quiz10...</p>")
        appendLine("</form>")
        appendLine("<script>document.getElementById('start-form').addEventListener('submit',function(){document.getElementById('preparing').style.display='block';});</script>")
    }

    fun renderQuestion(
        sessionId: String,
        playerName: String,
        topic: String,
        state: Quiz10FlowState.Question,
        correction: Correction? = null,
    ): String = page("Quiz10 - Pregunta ${state.questionNumber}") {
        appendLine("<h1>Quiz10</h1>")
        appendLine("<p><strong>Nombre:</strong> ${escapeHtml(playerName)}</p>")
        appendLine("<p><strong>Tema:</strong> ${escapeHtml(topic)}</p>")
        if (correction != null) {
            val prefix = if (correction.isCorrect) "✅ CORRECTO" else "❌ INCORRECTO"
            appendLine("<div class=\"correction\"><p>$prefix</p><p>Respuesta correcta: ${escapeHtml(correction.correctAnswer)}</p><p>${escapeHtml(correction.selectedFeedback)}</p></div>")
        }
        appendLine("<h2>Pregunta ${state.questionNumber}/10</h2>")
        appendLine("<p><strong>Área:</strong> ${escapeHtml(state.area)}</p>")
        appendLine("<p>${escapeHtml(state.question.text)}</p>")
        appendLine("<form method=\"post\" action=\"/games/${escapeHtml(sessionId)}/answer\">")
        state.question.options.forEachIndexed { index, option ->
            val letter = ('A' + index)
            appendLine("<button type=\"submit\" name=\"option\" value=\"$index\">$letter) ${escapeHtml(option)}</button>")
        }
        appendLine("</form>")
        appendLine("<p>Progreso: ${state.answeredQuestions}/10</p>")
        appendLine("<p>Aciertos: ${state.correctAnswers}</p>")
    }

    fun renderFinished(
        sessionId: String,
        playerProgress: PlayerProgress,
        finished: Quiz10FlowState.Finished,
        menu: Quiz10NavigationMenu,
    ): String = page("Quiz10 - Resultado") {
        appendLine("<h1>Partida terminada</h1>")
        appendLine("<p>Puntuación final ${finished.correctAnswers}/10</p>")
        appendLine("<h2>Progreso global</h2>")
        appendLine("<p>Nombre: ${escapeHtml(playerProgress.playerName)}</p>")
        appendLine("<p>Aciertos acumulados: ${playerProgress.correctAnswers}</p>")
        appendLine("<p>Fallos acumulados: ${playerProgress.incorrectAnswers}</p>")
        appendLine("<p>Porcentaje acumulado: ${playerProgress.accuracyPercent}%</p>")
        appendLine("<p>Estrellas: ⭐ ${playerProgress.stars}</p>")
        appendLine("<h2>Panel de navegación</h2>")
        appendLine("<form method=\"post\" action=\"/games/${escapeHtml(sessionId)}/navigation\">")
        menu.options.forEachIndexed { index, entry ->
            val optionNumber = index + 1
            val disabled = entry.option in setOf(
                Quiz10NavigationOption.VIEW_SOURCES,
                Quiz10NavigationOption.CREATE_IMAGE_QUIZ,
            )
            val attr = if (disabled) " disabled" else ""
            val suffix = if (disabled) " (todavía no disponible)" else ""
            appendLine("<button type=\"submit\" name=\"selection\" value=\"$optionNumber\"$attr>$optionNumber. ${escapeHtml(entry.label)}$suffix</button>")
        }
        appendLine("</form>")
    }

    fun renderChooseTopic(sessionId: String, playerName: String, currentSelection: String): String = page("Quiz10 - Elegir modalidad") {
        appendLine("<h1>Elegir modalidad o área</h1>")
        appendLine("<p>${escapeHtml(playerName)}, selecciona la modalidad para la siguiente partida.</p>")
        appendLine("<form method=\"post\" action=\"/games/${escapeHtml(sessionId)}/topic\" id=\"topic-form\">")
        appendLine("<label>Modalidad / Área")
        appendLine("<select name=\"selection\" required>")
        appendLine(selectionOptionsHtml(currentSelection))
        appendLine("</select>")
        appendLine("</label>")
        appendLine("<button type=\"submit\">Preparar Quiz10</button>")
        appendLine("<p id=\"preparing\" style=\"display:none\">Preparando Quiz10...</p>")
        appendLine("</form>")
        appendLine("<script>document.getElementById('topic-form').addEventListener('submit',function(){document.getElementById('preparing').style.display='block';});</script>")
    }

    fun renderFailedAnswers(sessionId: String, finished: Quiz10FlowState.Finished): String = page("Quiz10 - Repaso de fallos") {
        appendLine("<h1>Repaso de respuestas fallidas</h1>")
        if (finished.failedAnswers.isEmpty()) {
            appendLine("<p>No tienes respuestas fallidas en este Quiz10.</p>")
        } else {
            finished.failedAnswers.forEach { answer ->
                appendLine("<article>")
                appendLine("<p><strong>Pregunta ${answer.questionNumber}:</strong> ${escapeHtml(answer.question.text)}</p>")
                appendLine("<p>Tu respuesta: ${escapeHtml(answer.selectedAnswer)}</p>")
                appendLine("<p>Respuesta correcta: ${escapeHtml(answer.correctAnswer)}</p>")
                appendLine("</article>")
            }
        }
        appendLine("<form method=\"get\" action=\"/games/${escapeHtml(sessionId)}/panel\">")
        appendLine("<button type=\"submit\">Volver al panel</button>")
        appendLine("</form>")
    }

    fun renderBadRequest(message: String, backPath: String): String = page("Quiz10 - Error") {
        appendLine("<h1>Solicitud inválida</h1>")
        appendLine("<p>${escapeHtml(message)}</p>")
        appendLine("<a href=\"${escapeHtml(backPath)}\">Volver</a>")
    }

    fun renderNotFound(): String = page("Quiz10 - No encontrado") {
        appendLine("<h1>Sesión no encontrada</h1>")
        appendLine("<a href=\"/\">Volver al inicio</a>")
    }

    fun renderUnavailable(sessionId: String): String = page("Quiz10 - Opción no disponible") {
        appendLine("<p>Opción todavía no disponible.</p>")
        appendLine("<a href=\"/games/${escapeHtml(sessionId)}/panel\">Volver al panel</a>")
    }

    fun renderPreparationError(message: String = "No se pudo preparar Quiz10", backPath: String = "/"): String = page("Quiz10 - Error") {
        appendLine("<h1>${escapeHtml(message)}</h1>")
        appendLine("<p>Inténtalo de nuevo con otra modalidad o área.</p>")
        appendLine("<a href=\"${escapeHtml(backPath)}\">Volver</a>")
    }

    private fun selectionOptionsHtml(selected: String? = null): String {
        val lines = mutableListOf<String>()
        lines += optionHtml(RANDOM_SELECTION_VALUE, "🎲 Aleatorio (10 áreas distintas)", selected)
        Quiz10Area.catalog.forEach { area ->
            lines += optionHtml(area.label, area.label, selected)
        }
        return lines.joinToString("\n")
    }

    private fun optionHtml(value: String, label: String, selected: String?): String {
        val attr = if (value == selected) " selected" else ""
        return "<option value=\"${escapeHtml(value)}\"$attr>${escapeHtml(label)}</option>"
    }

    private fun page(title: String, body: StringBuilder.() -> Unit): String {
        val content = StringBuilder().apply(body).toString()
        return """
            <!doctype html>
            <html lang="es">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>${escapeHtml(title)}</title>
              <style>
                body { font-family: Georgia, serif; margin: 2rem auto; max-width: 760px; padding: 0 1rem; background: #f7f4ea; color: #1e1b18; }
                h1, h2 { color: #2d3a2e; }
                form { display: grid; gap: .75rem; margin: 1rem 0; }
                button { text-align: left; padding: .65rem .8rem; border: 1px solid #6c7d62; background: #fefcf5; cursor: pointer; }
                button[disabled] { color: #6f6f6f; border-color: #b6b6b6; cursor: not-allowed; }
                label { display: grid; gap: .35rem; }
                input { padding: .5rem; border: 1px solid #8c8c8c; }
                .error { color: #8d1f1f; }
                .correction { border-left: 4px solid #2f6f4f; padding-left: .75rem; margin-bottom: 1rem; }
              </style>
            </head>
            <body>
              $content
            </body>
            </html>
        """.trimIndent()
    }

    private fun escapeHtml(value: String): String = buildString(value.length) {
        value.forEach { ch ->
            append(
                when (ch) {
                    '&' -> "&amp;"
                    '<' -> "&lt;"
                    '>' -> "&gt;"
                    '"' -> "&quot;"
                    '\'' -> "&#39;"
                    else -> ch
                },
            )
        }
    }
}
