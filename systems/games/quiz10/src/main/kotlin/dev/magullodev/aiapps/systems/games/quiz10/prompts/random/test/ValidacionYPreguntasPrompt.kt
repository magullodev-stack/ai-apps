package dev.magullodev.aiapps.systems.games.quiz10.prompts.random.test

import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute

internal fun validacionYPreguntasPrompt(route: CoverageRoute): String {
    val routeRows = route.items.mapIndexed { index, item ->
        "| ${index + 1} | ${difficultyLabel(item.difficulty)} | ${item.area} | ${item.group} | ${item.referent} | ${item.knowledge} | ${item.answer} |"
    }.joinToString("\n")

    return """
        Grupo: ámbito de conocimiento dentro del área.
        Referente: elemento del grupo sobre el que se selecciona un conocimiento.
        Conocimiento: hecho, propiedad o relación verificable sobre el referente.

        Verifica la coherencia entre área, grupo, referente y conocimiento, así como la exactitud de cada respuesta.

        Verifica que cada conocimiento corresponde a la dificultad asignada y que ninguna fila evalúa un conocimiento repetido o equivalente.

        Evalúa la dificultad por la probabilidad de que una persona con cultura general conozca la respuesta, no por su complejidad técnica, especialización académica ni dificultad de redacción.

        Para cada fila válida, genera una pregunta inequívoca y tres distractores plausibles, distintos e incorrectos, sin alterar el conocimiento ni la respuesta. Marca como inválida cualquier fila que no cumpla estas condiciones.

        ## RUTA DE COBERTURA

        | N.º | Dificultad | Área | Grupo | Referente | Conocimiento | Respuesta |
        | --- | --- | --- | --- | --- | --- | --- |
        $routeRows

        ## RESULTADO

        | N.º | Válida | Incidencia | Pregunta | Respuesta | Distractor 1 | Distractor 2 | Distractor 3 |
        |---|---|---|---|---|---|---|---|
        | 1 | | | | | | | |
        | 2 | | | | | | | |
        | 3 | | | | | | | |
        | 4 | | | | | | | |
        | 5 | | | | | | | |
        | 6 | | | | | | | |
        | 7 | | | | | | | |
        | 8 | | | | | | | |
        | 9 | | | | | | | |
        | 10 | | | | | | | |

        La tabla de resultado es la plantilla conceptual del trabajo; la respuesta efectiva del modelo debe ajustarse al esquema de generación estructurada de la API.
    """.trimIndent()
}

private fun difficultyLabel(difficulty: CoverageDifficulty): String =
    when (difficulty) {
        CoverageDifficulty.EASY -> "Fácil"
        CoverageDifficulty.MODERATE -> "Moderado"
        CoverageDifficulty.HARD -> "Difícil"
        CoverageDifficulty.VERY_HARD -> "Muy difícil"
    }