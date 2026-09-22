package dev.magullodev.aiapps.systems.games.quiz10.coverage.terra

internal object TerraCoverageRouteValidationPrompt {
    const val TEXT = """
Valida cada fila de la ruta de cobertura y genera una pregunta por cada fila válida.

Comprueba que el conocimiento corresponda al área, grupo y referente indicados, y que la respuesta sea correcta, precisa e inequívoca.

Formula una pregunta que evalúe exactamente ese conocimiento y genera tres distractores plausibles, distintos e incorrectos. Entre las cuatro opciones debe haber una única respuesta correcta.

Si una fila no permite generar una pregunta válida, márcala como inválida e indica brevemente el motivo.

## RUTA DE COBERTURA

[RUTA GENERADA POR TERRA 1]

## RESULTADO

| N.º | Válida | Incidencia | Pregunta | Respuesta | Distractor 1 | Distractor 2 | Distractor 3 |
|---|---|---|---|---|---|---|---|
| [N.º] | | | | | | | |
"""
}
