package dev.magullodev.aiapps.systems.games.quiz10.coverage.terra

import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty

internal fun terraReplacementQuestionPrompt(
    pendingPositions: List<ReplacementQuestionPosition>,
    acceptedQuestions: List<AcceptedCoverageQuestion>,
): String {
    val pendingRows = pendingPositions.joinToString("\n") { position ->
        "| ${position.position} | ${difficultyLabel(position.difficulty)} | ${position.areaLabel} |"
    }

    val acceptedSection = if (acceptedQuestions.isEmpty()) {
        "(Sin preguntas aceptadas todavía)"
    } else {
        acceptedQuestions.joinToString("\n") { accepted ->
            "- ${accepted.position}. ${accepted.question} -> ${accepted.answer}"
        }
    }

    val resultRows = pendingPositions.joinToString("\n") { position ->
        "| ${position.position} |  |  |  |  |  |"
    }

    return """
        Genera una pregunta de sustitución por cada posición indicada.

        Selecciona libremente un conocimiento dentro del área asignada. Evalúa la dificultad por la probabilidad de que una persona con cultura general conozca la respuesta, no por su complejidad técnica, especialización académica ni dificultad de redacción.

        Evita conocimientos repetidos o equivalentes a los de las preguntas ya aceptadas y a los de las demás sustituciones. Cada pregunta debe ser inequívoca y contener una respuesta correcta, precisa y verificable, y tres distractores plausibles, distintos e incorrectos.

        ## POSICIONES POR SUSTITUIR

        | N.º | Dificultad | Área |
        |---|---|---|
        $pendingRows

        ## PREGUNTAS YA ACEPTADAS

        $acceptedSection

        ## RESULTADO

        | N.º | Pregunta | Respuesta | Distractor 1 | Distractor 2 | Distractor 3 |
        |---|---|---|---|---|---|
        $resultRows

        La tabla RESULTADO representa el trabajo solicitado; la respuesta efectiva debe ajustarse al esquema estructurado de la API.
    """.trimIndent()
}

private fun difficultyLabel(difficulty: CoverageDifficulty): String =
    when (difficulty) {
        CoverageDifficulty.EASY -> "Fácil"
        CoverageDifficulty.MODERATE -> "Moderado"
        CoverageDifficulty.HARD -> "Difícil"
        CoverageDifficulty.VERY_HARD -> "Muy difícil"
    }
