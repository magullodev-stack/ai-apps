package dev.magullodev.aiapps.systems.games.quiz10.random.prompts

import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación.CoverageRoute

internal object TerraCoverageRouteValidationPrompt {
    const val TEXT = """
Valida cada fila de la ruta de cobertura y genera una pregunta para cada una de las diez posiciones.

Comprueba que el conocimiento corresponda al área, grupo y referente indicados, y que la respuesta sea correcta, precisa e inequívoca. Verifica la dificultad asignada y evita conocimientos repetidos o equivalentes.

Si la fila es válida, formula una pregunta que evalúe exactamente ese conocimiento, conserva literalmente la respuesta original y genera tres distractores plausibles, distintos e incorrectos. Entre las cuatro opciones debe haber una única respuesta correcta.

Si una fila no permite generar una pregunta válida, selecciona otro conocimiento de la misma área y dificultad, genera una pregunta válida con su respuesta y tres distractores plausibles, distintos e incorrectos, e indica brevemente el motivo de la sustitución en «Incidencia».

Marca «Sí» en «Válida» cuando se conserve el conocimiento original y «No» cuando haya sido necesario sustituirlo. Completa las diez posiciones sin dejar preguntas pendientes.

## RUTA DE COBERTURA

| N.º | Dificultad | Área | Grupo | Referente | Conocimiento | Respuesta |
|---|---|---|---|---|---|---|
[RUTA GENERADA POR TERRA 1]

## RESULTADO

| N.º | Válida | Incidencia | Pregunta | Respuesta | Distractor 1 | Distractor 2 | Distractor 3 |
|---|---|---|---|---|---|---|---|
| [N.º] | | | | | | | |

Devuelve el JSON del esquema de la API en el mismo orden: valid=true e issue vacío si conservas la fila; valid=false e issue con el motivo si la sustituyes. En ambos casos rellena question, answer y los tres distractores.
"""
}

internal fun terraCoverageRouteValidationPrompt(topic: String, route: CoverageRoute): String {
    val rows = route.items.mapIndexed { index, item ->
        val difficulty = when (item.difficulty) {
            CoverageDifficulty.EASY -> "Fácil"
            CoverageDifficulty.MODERATE -> "Moderado"
            CoverageDifficulty.HARD -> "Difícil"
            CoverageDifficulty.VERY_HARD -> "Muy difícil"
        }
        "| ${index + 1} | $difficulty | ${item.area} | ${item.group} | ${item.referent} | ${item.knowledge} | ${item.answer} |"
    }.joinToString("\n")

    return TerraCoverageRouteValidationPrompt.TEXT
        .replace("[RUTA GENERADA POR TERRA 1]", rows)
        .let { if (topic.isBlank()) it else it + "\n\nTema: $topic" }
}
