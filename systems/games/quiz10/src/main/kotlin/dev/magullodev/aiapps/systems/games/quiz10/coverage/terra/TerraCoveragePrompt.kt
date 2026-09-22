package dev.magullodev.aiapps.systems.games.quiz10.coverage.terra

internal object TerraCoveragePrompt {
    const val TEXT = """
Completa la ruta de cobertura.

Grupo: ámbito de conocimiento dentro del área.
Referente: elemento del grupo sobre el que se selecciona un conocimiento.
Conocimiento: hecho, propiedad o relación verificable sobre el referente.

Genera grupos, referentes y conocimientos diversificados dentro de cada área. Evita repeticiones, solapamientos y la concentración en los referentes más habituales.

Selecciona conocimientos verificables cuya dificultad corresponda a la asignada. Evalúa la dificultad por la probabilidad de que una persona con cultura general conozca la respuesta, no por su complejidad técnica, especialización académica ni dificultad de redacción. Cada respuesta debe ser precisa e inequívoca.

## RUTA DE COBERTURA

| N.º | Dificultad | Área | Grupo | Referente | Conocimiento | Respuesta |
|---|---|---|---|---|---|---|
| 1 | Fácil | [ÁREA 1] | | | | |
| 2 | Fácil | [ÁREA 2] | | | | |
| 3 | Fácil | [ÁREA 3] | | | | |
| 4 | Fácil | [ÁREA 4] | | | | |
| 5 | Moderado | [ÁREA 5] | | | | |
| 6 | Moderado | [ÁREA 6] | | | | |
| 7 | Moderado | [ÁREA 7] | | | | |
| 8 | Difícil | [ÁREA 8] | | | | |
| 9 | Difícil | [ÁREA 9] | | | | |
| 10 | Muy difícil | [ÁREA 10] | | | | |
"""
}
