const String quiz10LunaPrompt = '''Para cada fila i, primero selecciona una Rᵢ factual, concreta y verificable.
Después formula Qᵢ conforme a Pᵢ y Dᵢ, de modo que Rᵢ sea una respuesta correcta.

dif(Rᵢ): dificultad estimada de conocer Rᵢ.

max(dif(R₁),...,dif(R₄)) < min(dif(R₅),...,dif(R₇))
max(dif(R₅),...,dif(R₇)) < min(dif(R₈),dif(R₉))
max(dif(R₈),dif(R₉)) < dif(R₁₀)

4 ≤ palabras(Qᵢ) ≤ 24
1 ≤ palabras(Rᵢ) ≤ 8

C = {(Rᵢ,Rⱼ): 1 ≤ j < i ≤ 10}
    ∪ ⋃ᵢ₌₁¹⁰ (
        PalabrasYExpresiones(Qᵢ)
        × ({Rᵢ} ∪ AliasYFragmentos(Rᵢ))
      )

∀(x,y) ∈ C: x ≠literal y ∧ x ≢semántica y''';