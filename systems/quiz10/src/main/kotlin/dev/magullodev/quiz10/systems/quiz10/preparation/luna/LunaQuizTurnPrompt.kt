package dev.magullodev.quiz10.systems.quiz10.preparation.luna

internal fun lunaTurnPrompt(
    area: String,
    group: String,
    referent: String,
    knowledge: String,
    answer: String,
): String = """
    Genera un único turno de Quiz10 usando exclusivamente este contexto canónico:

    area: $area
    group: $group
    referent: $referent
    knowledge: $knowledge
    answer: $answer

    Reglas obligatorias:
    - Formula una pregunta que evalúe exactamente knowledge sobre referent.
    - Usa solo el contexto necesario de group y area para que la pregunta sea clara.
    - Devuelve solo estos campos: question, correctExplanation y distractors.
    - distractors debe contener exactamente 3 elementos.
    - Cada distractor debe incluir solo text y explanation.
    - Los textos y explicaciones deben ser no vacíos.
    - Los distractores deben ser plausibles pero falsos.
    - Los distractores deben ser distintos entre sí y distintos de answer (ignorando mayúsculas y espacios exteriores).
    - No cambies answer: la respuesta correcta real la inyecta el sistema.
    - No decidas ni sugieras la posición A/B/C/D de la respuesta correcta.
""".trimIndent()
