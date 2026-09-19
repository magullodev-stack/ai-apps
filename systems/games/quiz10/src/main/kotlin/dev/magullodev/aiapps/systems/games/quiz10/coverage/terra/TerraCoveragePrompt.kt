package dev.magullodev.aiapps.systems.games.quiz10.coverage.terra

import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.coverage.StandardCoveragePlan

internal fun terraCoveragePrompt(topic: String): String = """
    Tema: [  ]

    ---

    ## DEFINICIONES

    **[ÁREA]**
    Faceta principal de **[TEMA]**.

    **[GRUPO]**
    Subtema dentro de **[ÁREA]**.

    **[REFERENTE]**
    Elemento concreto dentro de **[GRUPO]** sobre el que se pregunta.

    **[CONOCIMIENTO]**
    Hecho, propiedad o relación evaluada sobre **[REFERENTE]**.

    **[RESPUESTA]**
    Solución exacta esperada.

    ### REGLAS DE CLASIFICACIÓN

    Adapta el nivel de detalle de **[ÁREA]**, **[GRUPO]** y **[REFERENTE]** a la amplitud de **[TEMA]**.

    Áreas o grupos equivalentes o sustancialmente solapados cuentan como una misma categoría.

    ---

    ## DIFICULTAD

    La dificultad se determina por el nivel de conocimiento necesario para identificar correctamente la **[RESPUESTA]**:

    - **Fácil — Filas 1–4:** respuestas identificables mediante conocimientos habituales y ampliamente conocidos.
    - **Moderado — Filas 5–7:** respuestas que requieren conocimientos menos comunes o cierta familiaridad específica.
    - **Difícil — Filas 8–9:** respuestas que requieren conocimientos especializados.
    - **Muy difícil — Fila 10:** respuestas que requieren conocimientos excepcionalmente precisos, avanzados o poco conocidos.

    ---

    ## INSTRUCCIONES

    Completa la RUTA DE COBERTURA buscando la máxima diversidad posible dentro de [TEMA]. No repitas [REFERENTE] entre filas y evita repetir [ÁREA] o [GRUPO] cuando existan alternativas naturales.

    Selecciona el [CONOCIMIENTO] y la [RESPUESTA] de cada fila de modo que su dificultad corresponda a la DIFICULTAD asignada.

    ---

    ## RUTA DE COBERTURA

    Cada fila sigue este formato:

    **[n]. [DIFICULTAD] · [ÁREA] · [GRUPO] · [REFERENTE] · [CONOCIMIENTO] · [RESPUESTA]**

    Contrato conceptual canónico: **dificultad · área · grupo · referente · conocimiento · respuesta**.

    La **[DIFICULTAD]** está fijada por la fila y no debe reinterpretarse ni alterarse.

    1. Fácil · [ÁREA] · [GRUPO] · [REFERENTE] · [CONOCIMIENTO] · [RESPUESTA]
    2. Fácil · [ÁREA] · [GRUPO] · [REFERENTE] · [CONOCIMIENTO] · [RESPUESTA]
    3. Fácil · [ÁREA] · [GRUPO] · [REFERENTE] · [CONOCIMIENTO] · [RESPUESTA]
    4. Fácil · [ÁREA] · [GRUPO] · [REFERENTE] · [CONOCIMIENTO] · [RESPUESTA]
    5. Moderado · [ÁREA] · [GRUPO] · [REFERENTE] · [CONOCIMIENTO] · [RESPUESTA]
    6. Moderado · [ÁREA] · [GRUPO] · [REFERENTE] · [CONOCIMIENTO] · [RESPUESTA]
    7. Moderado · [ÁREA] · [GRUPO] · [REFERENTE] · [CONOCIMIENTO] · [RESPUESTA]
    8. Difícil · [ÁREA] · [GRUPO] · [REFERENTE] · [CONOCIMIENTO] · [RESPUESTA]
    9. Difícil · [ÁREA] · [GRUPO] · [REFERENTE] · [CONOCIMIENTO] · [RESPUESTA]
    10. Muy difícil · [ÁREA] · [GRUPO] · [REFERENTE] · [CONOCIMIENTO] · [RESPUESTA]
""".trimIndent().replaceFirst("Tema: [  ]", "Tema: [$topic]")

internal fun terraCoveragePrompt(plan: StandardCoveragePlan): String {
    val rows = plan.positions.joinToString("\n") { position ->
        "| ${position.position} | ${difficultyLabel(position.difficulty)} | ${position.area.label} |  |  |  |  |"
    }

    return """
        Completa la ruta de cobertura.

        Grupo: ámbito de conocimiento dentro del área.
        Referente: elemento del grupo sobre el que se selecciona un conocimiento.
        Conocimiento: hecho, propiedad o relación verificable sobre el referente.

        Genera grupos, referentes y conocimientos diversificados dentro de cada área. Evita repeticiones, solapamientos y la concentración en los referentes más habituales.

        Selecciona conocimientos verificables cuya dificultad corresponda a la asignada. Evalúa la dificultad por la probabilidad de que una persona con cultura general conozca la respuesta, no por su complejidad técnica, especialización académica ni dificultad de redacción. Cada respuesta debe ser precisa e inequívoca.

        ## RUTA DE COBERTURA

        | N.º | Dificultad | Área | Grupo | Referente | Conocimiento | Respuesta |
        | --- | --- | --- | --- | --- | --- | --- |
        $rows
    """.trimIndent()
}

private fun difficultyLabel(difficulty: CoverageDifficulty): String =
    when (difficulty) {
        CoverageDifficulty.EASY -> "Fácil"
        CoverageDifficulty.MODERATE -> "Moderado"
        CoverageDifficulty.HARD -> "Difícil"
        CoverageDifficulty.VERY_HARD -> "Muy difícil"
    }
