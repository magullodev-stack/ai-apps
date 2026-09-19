package dev.magullodev.aiapps.ui.quiz10.web

import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRouteItem
import dev.magullodev.aiapps.systems.games.quiz10.navigation.Quiz10NavigationMenu
import dev.magullodev.aiapps.systems.games.quiz10.preparation.PreparedQuiz
import dev.magullodev.aiapps.systems.games.quiz10.progress.PlayerProgress
import dev.magullodev.aiapps.systems.games.quiz10.question.QuizQuestion
import dev.magullodev.aiapps.systems.games.quiz10.result.QuizAnswerRecord
import dev.magullodev.aiapps.systems.games.quiz10.session.Quiz10FlowState
import kotlin.test.Test
import kotlin.test.assertContains
import kotlin.test.assertFalse

class Quiz10WebRendererTest {
    private val renderer = Quiz10WebRenderer()

    @Test
    fun rendersInitialForm() {
        val html = renderer.renderHome()

        assertContains(html, "Nombre")
        assertContains(html, "Modalidad / Área")
        assertContains(html, "Aleatorio (10 áreas distintas)")
        assertContains(html, "Empezar Quiz10")
    }

    @Test
    fun rendersFourClickableOptionsForQuestion() {
        val state = Quiz10FlowState.Question(
            topic = "Tema",
            questionNumber = 1,
            totalQuestions = 10,
            area = "History",
            question = QuizQuestion("Q", listOf("A", "B", "C", "D"), listOf("FA", "FB", "FC", "FD"), 0),
            answeredQuestions = 0,
            correctAnswers = 0,
        )

        val html = renderer.renderQuestion("session-1", "Ada", "Tema", state)

        assertContains(html, "value=\"0\"")
        assertContains(html, "value=\"1\"")
        assertContains(html, "value=\"2\"")
        assertContains(html, "value=\"3\"")
        assertFalse(html.contains("Luna"))
        assertFalse(html.contains("Cargando comentario"))
    }

    @Test
    fun rendersQuestionAndProgress() {
        val state = Quiz10FlowState.Question(
            topic = "Tema",
            questionNumber = 2,
            totalQuestions = 10,
            area = "History",
            question = QuizQuestion("Capital?", listOf("A", "B", "C", "D"), listOf("FA", "FB", "FC", "FD"), 1),
            answeredQuestions = 1,
            correctAnswers = 1,
        )

        val html = renderer.renderQuestion(
            sessionId = "session-1",
            playerName = "Ada",
            topic = "Tema",
            state = state,
            correction = Quiz10WebRenderer.Correction(isCorrect = false, correctAnswer = "B", selectedFeedback = "Porque A contradice el dato."),
        )

        assertContains(html, "Pregunta 2/10")
        assertContains(html, "Área:")
        assertContains(html, "Progreso: 1/10")
        assertContains(html, "Aciertos: 1")
        assertContains(html, "❌ INCORRECTO")
        assertContains(html, "Respuesta correcta: B")
        assertContains(html, "Porque A contradice el dato.")
    }

    @Test
    fun rendersResultProgressStarsAndFinalPanel() {
        val progress = PlayerProgress.start("Ada").recordQuiz(10)
        val finished = finishedState(correctAnswers = 10, failedIndices = emptyList())
        val menu = Quiz10NavigationMenu.forTopic("Historia")

        val html = renderer.renderFinished("session-1", progress, finished, menu)

        assertContains(html, "Puntuación final 10/10")
        assertContains(html, "Aciertos acumulados: 10")
        assertContains(html, "Fallos acumulados: 0")
        assertContains(html, "Porcentaje acumulado: 100%")
        assertContains(html, "Estrellas: ⭐ 1")
        assertContains(html, "Panel de navegación")
        assertContains(html, "1. 🔂 Otro Quiz10 de Historia")
        assertFalse(html.contains("Luna"))
    }

    @Test
    fun rendersFailedAnswersReview() {
        val finished = finishedState(correctAnswers = 8, failedIndices = listOf(2, 7))

        val html = renderer.renderFailedAnswers("session-1", finished)

        assertContains(html, "Repaso de respuestas fallidas")
        assertContains(html, "Pregunta 2")
        assertContains(html, "Tu respuesta")
        assertContains(html, "Respuesta correcta")
        assertContains(html, "Volver al panel")
    }

    @Test
    fun escapesDynamicHtmlInNameTopicQuestionAndOptions() {
        val dangerousName = "<Ada & Bob>"
        val dangerousTopic = "Tema \"X\" <script>"
        val state = Quiz10FlowState.Question(
            topic = dangerousTopic,
            questionNumber = 1,
            totalQuestions = 10,
            area = "A & B",
            question = QuizQuestion("<Q?>", listOf("<A>", "\"B\"", "C & D", "'E'"), listOf("<FA>", "\"FB\"", "FC & FD", "'FE'"), 0),
            answeredQuestions = 0,
            correctAnswers = 0,
        )

        val html = renderer.renderQuestion(
            "session-1",
            dangerousName,
            dangerousTopic,
            state,
            correction = Quiz10WebRenderer.Correction(
                isCorrect = false,
                correctAnswer = "<Correct>",
                selectedFeedback = "<b>Feedback & detalle</b>",
            ),
        )

        assertContains(html, "&lt;Ada &amp; Bob&gt;")
        assertContains(html, "Tema &quot;X&quot; &lt;script&gt;")
        assertContains(html, "&lt;Q?&gt;")
        assertContains(html, "&lt;A&gt;")
        assertContains(html, "&quot;B&quot;")
        assertContains(html, "C &amp; D")
        assertContains(html, "&#39;E&#39;")
        assertContains(html, "&lt;b&gt;Feedback &amp; detalle&lt;/b&gt;")
    }

    private fun finishedState(correctAnswers: Int, failedIndices: List<Int>): Quiz10FlowState.Finished {
        val route = CoverageRoute.of(List(10) { index ->
            CoverageRouteItem(
                difficulty = when (index) {
                    in 0..3 -> CoverageDifficulty.EASY
                    in 4..6 -> CoverageDifficulty.MODERATE
                    in 7..8 -> CoverageDifficulty.HARD
                    else -> CoverageDifficulty.VERY_HARD
                },
                area = "Area $index",
                group = "Group",
                referent = "Ref $index",
                knowledge = "Know",
                answer = "Ans",
            )
        })
        PreparedQuiz(
            topic = "Historia",
            route = route,
        )
        val questions = List(10) { index ->
            QuizQuestion(
                "Question $index",
                listOf("A", "B", "C", "D"),
                listOf("FA", "FB", "FC", "FD"),
                PreparedQuiz.correctOptionSequence[index],
            )
        }
        val records = questions.mapIndexed { idx, q ->
            val selected = if ((idx + 1) in failedIndices) (q.correctOptionIndex + 1) % 4 else q.correctOptionIndex
            QuizAnswerRecord(idx + 1, "Area $idx", q, selected)
        }
        return Quiz10FlowState.Finished(
            topic = "Historia",
            totalQuestions = 10,
            correctAnswers = correctAnswers,
            answers = records,
            failedAnswers = records.filter { !it.isCorrect },
        )
    }
}
