package dev.magullodev.aiapps.systems.games.quiz10.coverage.terra

import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageDifficulty
import dev.magullodev.aiapps.systems.games.quiz10.coverage.CoverageRoute

internal fun terraCoverageRouteValidationPrompt(topic: String, route: CoverageRoute): String {
    val routeLines = route.items.mapIndexed { index, item ->
        "${index + 1}. ${difficultyLabel(item.difficulty)} · ${item.area} · ${item.group} · ${item.referent} · ${item.knowledge} · ${item.answer}"
    }.joinToString("\n")

    return """
        Tema solicitado: [$topic]

        Vas a revisar críticamente una RUTA DE COBERTURA ya generada. No debes regenerar ni reescribir la ruta.
        Evalúa el tema completo y las relaciones entre las diez posiciones de forma global.

        Contrato canónico por posición:
        - dificultad
        - área
        - grupo
        - referente
        - conocimiento
        - respuesta

        Ruta recibida (10 posiciones):
        $routeLines

        Criterios obligatorios de revisión:
        1) Las áreas y grupos representan divisiones coherentes del tema, con niveles de abstracción apropiados y sin solapamientos sustanciales injustificados.
        2) Los dominios conceptuales identificados son autónomos cuando la clasificación utilizada así lo exige.
        3) Cada referente pertenece al grupo y área correspondientes.
        4) Cada conocimiento pertenece al tema solicitado y al referente seleccionado.
        5) Cada respuesta es correcta, precisa y coherente con el conocimiento que pretende evaluarse.
        6) La dificultad asignada en cada posición corresponde razonablemente al conocimiento necesario para identificar la respuesta.
        7) La ruta presenta diversidad suficiente y evita repeticiones conceptuales innecesarias.
        8) La ruta no contiene elementos absurdos, anacrónicos, contradictorios o ajenos al tema.
        9) La ruta respeta la estructura y las restricciones existentes de la ruta de cobertura.

        Debes devolver solo JSON válido que siga exactamente el esquema estructurado proporcionado.
        Tu salida es una evaluación crítica de esta ruta concreta; no generes una ruta alternativa.

        Reglas del resultado:
        - Si la ruta es admisible: approved=true e issues=[]
        - Si la ruta no es admisible: approved=false y issues con al menos una incidencia concreta
    """.trimIndent()
}

private fun difficultyLabel(difficulty: CoverageDifficulty): String = when (difficulty) {
    CoverageDifficulty.EASY -> "Fácil"
    CoverageDifficulty.MODERATE -> "Moderado"
    CoverageDifficulty.HARD -> "Difícil"
    CoverageDifficulty.VERY_HARD -> "Muy difícil"
}
