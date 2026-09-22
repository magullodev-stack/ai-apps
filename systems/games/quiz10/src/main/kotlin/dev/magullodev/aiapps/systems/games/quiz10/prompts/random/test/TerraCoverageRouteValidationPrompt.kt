package dev.magullodev.aiapps.systems.games.quiz10.prompts.random.test

internal object TerraCoverageRouteValidationPrompt {
    const val TEXT = """
Valida cada fila de la ruta de cobertura y genera una pregunta para cada una de las diez posiciones.

Comprueba que el conocimiento corresponda al área, grupo y referente indicados, y que la respuesta sea correcta, precisa e inequívoca.

Si la fila es válida, formula una pregunta que evalúe exactamente ese conocimiento y genera tres distractores plausibles, distintos e incorrectos. Entre las cuatro opciones debe haber una única respuesta correcta.

Si una fila no permite generar una pregunta válida, selecciona otro conocimiento de la misma área y dificultad, genera una pregunta válida con su respuesta y tres distractores plausibles, distintos e incorrectos, e indica brevemente el motivo de la sustitución en «Incidencia».

Marca «Sí» en «Válida» cuando se conserve el conocimiento original y «No» cuando haya sido necesario sustituirlo. Completa las diez posiciones sin dejar preguntas pendientes.

## RUTA DE COBERTURA

[RUTA GENERADA POR TERRA 1]

## RESULTADO

| N.º | Válida | Incidencia | Pregunta | Respuesta | Distractor 1 | Distractor 2 | Distractor 3 |
|---|---|---|---|---|---|---|---|
| [N.º] | | | | | | | |
"""
}

internal fun terraCoverageRouteValidationPrompt(
    topic: String,
    route: dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute,
): String {
    val rows = route.items.mapIndexed { index, item ->
        "| ${index + 1} | ${item.difficulty} | ${item.area} | ${item.group} | ${item.referent} | ${item.knowledge} | ${item.answer} |"
    }.joinToString("\n")

    return TerraCoverageRouteValidationPrompt.TEXT
        .replace("[RUTA GENERADA POR TERRA 1]", rows)
        .plus("\n\nTema: $topic")
}
