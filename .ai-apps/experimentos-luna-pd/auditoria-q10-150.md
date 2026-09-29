# Auditoría de las 150 preguntas número 10 de Luna

**Objeto:** únicamente la décima Q/R de cada una de las 50 llamadas de los tres experimentos (150 Q/R). No se alteró ningún prompt, generador ni resultado original.

**Advertencia metodológica:** revisión cualitativa provisional de los textos originales; no constituye calibración de dificultad con jugadores, validación factual independiente por Terra ni una verificación de la desigualdad con las preguntas 1–9. Las etiquetas **S, A, L, T y H** son señales que hay que revisar, no errores factuales demostrados. **«Sin señal clara» no significa «validada».**

## Fuentes y comparabilidad

- **Con D, sin U:** [JSONL original](https://github.com/magullodev-stack/ai-apps/blob/dev/.ai-apps/experimentos-luna-pd/luna-pd-2026-09-29T18-20-32-129938Z.jsonl); 50 llamadas correctas, 50 Q10 extraídas.
- **Sin D, sin U:** [JSONL original](https://github.com/magullodev-stack/ai-apps/blob/dev/.ai-apps/experimentos-luna-pd/luna-p-2026-09-29T19-05-33-571516Z.jsonl); 50 llamadas correctas, 50 Q10 extraídas.
- **Sin D, con U:** [JSONL original](https://github.com/magullodev-stack/ai-apps/blob/dev/.ai-apps/experimentos-luna-pd/luna-pu-2026-09-29T19-26-51-435641Z.jsonl); 50 llamadas correctas, 50 Q10 extraídas.

Cada llamada i utiliza el mismo pivote P y dificultad «Muy difícil» en los tres experimentos; los prompts difieren por el uso de D y U. En P+U, U se reinicia después de diez llamadas. Las coincidencias entre experimentos no se consideran fallos de repetición.

## Taxonomía para el siguiente modelo

- **E — Respuesta filtrada (literal, epónimo o alias).**
- **A — Respuesta o pregunta poco unívoca.**
- **S — Dificultad máxima dudosa.**
- **H — Pista fuerte, sin respuesta literal.**
- **L — R explicativa o larga (riesgo para distractores).**
- **T — Redacción forzada o metalingüística.**
- **R — Hecho repetido en otra llamada del mismo modo.**
- **—**: sin una señal evidente en esta revisión; mantener pendiente de revisión factual y calibración con jugadores.

Las etiquetas pueden coexistir en una misma pregunta; los recuentos por clase **no son sumables**. «R» compara el mismo hecho dentro de cada uno de los tres experimentos; con U se señala también la repetición **entre bloques**, que no incumple la condición del experimento.

## Recuento provisional

| Experimento | Q10 | Sin señales | E | A | S | H | L | T | R |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Con D, sin U | 50 | 24 | 4 | 6 | 5 | 0 | 13 | 7 | 0 |
| Sin D, sin U | 50 | 36 | 1 | 0 | 4 | 0 | 0 | 0 | 9 |
| Sin D, con U | 50 | 36 | 2 | 1 | 6 | 2 | 0 | 0 | 4 |

**Ejemplos inequívocos que justifican controles automáticos:**

- D, llamada 9: Q incluye «alcance léxico» y R es «El alcance léxico» (**E**).
- D, llamada 44: Q plantea «determinar quién fue su creador» y R es «La autoría» (**E**).
- P, llamada 21: Q menciona enlaces «rojo o negro» y R es «Árbol rojo-negro» (**E**).
- P+U, llamada 40: Q menciona «Edmund Gettier» y R es «Problema de Gettier» (**E**).
- D, llamada 1: Q y R usan una expresión curatorial amplia, difícil de identificar inequívocamente (**A, T**).
- P+U, llamadas 4, 17 y 41: reaparece Rietveld/Casa Schröder entre bloques independientes (**R**, no incumple U).

## Instrucciones concretas candidatas para Terra (no implementadas)

1. **Comprobar Q y R juntas.** Detectar respuestas que el enunciado ya revela, incluidas paráfrasis transparentes, epónimos y alias (E). Si ocurre, no aceptar solo porque R sea un término técnico.
2. **Calibrar la dificultad de la pregunta, no la rareza del nombre.** Una R especializada puede quedar trivial por la pista de Q. Para la posición 10, pedir un conocimiento realmente discriminante para público de cultura general; si resulta introductoria, marcar S y solicitar otra Q/R.
3. **Comprobar univocidad factual.** Determinar si con Q existe una sola R correcta y verificable; marcar A ante un referente genérico, múltiples respuestas posibles o una denominación no consolidada. Si no se puede verificar, solicitar revisión adicional.
4. **Preferir respuestas de selección múltiple cerradas.** R debería poder presentarse y contrastarse con tres distractores razonables. Una frase larga o enumeración puede ser correcta, pero se debe evaluar si complica la validación y los distractores (L).
5. **Exigir una pregunta natural.** Marcar T cuando la redacción parezca construida para cumplir D, en vez de pedir un hecho de cultura general de manera autónoma.
6. **Detectar repeticiones por identidad del hecho.** Comparar también variaciones de artículos, traducciones, símbolos, alias y preguntas diferentes con la misma respuesta o hecho; respetar el alcance de U y distinguir duplicados entre bloques (R).
7. **Validar hechos antes de aceptar.** Esta auditoría no sustituye la comprobación factual independiente; si la evidencia es insuficiente, registrar «por verificar» y no inventar una corrección.
8. **Para probar la progresión completa**, comparar además Q10 con Q9 y el resto de cada llamada. Este conjunto de 150 Q10 permite identificar fallos de la última pregunta, pero no demostrar el orden de dificultad dentro de la partida.

## Inventario íntegro: 150 Q10, Q y R originales

Las notas describen el **riesgo observado o la razón de la señal**, no una verificación factual externa.

### Con D, sin U

| Llamada | P | D | Q10 (literal) | R10 (literal) | Señales | Motivo |
|---:|---|---|---|---|---|---|
| 1 | Arte | D32 | En la interpretación de una obra de arte, ¿qué elemento curatorial establece qué aspectos, límites y aplicaciones del contenido deben considerarse pertinentes? | El marco interpretativo curatorial | A, T | «Marco interpretativo curatorial» es genérico; falta un referente unívoco y la redacción parece condicionada por D. |
| 2 | Derecho | D69 | En el derecho procesal español, ¿cómo se denomina la intervención de un tercero que afirma ser propietario de los bienes embargados en un procedimiento de ejecución? | Tercería de dominio. | — | — |
| 3 | Química | D21 | ¿Qué principio químico establece que un sistema en equilibrio se desplaza para contrarrestar una modificación de sus condiciones? | El principio de Le Châtelier | — | — |
| 4 | Arquitectura | D27 | ¿Qué elemento arquitectónico transmite al exterior el empuje lateral de una bóveda gótica? | El arbotante | — | — |
| 5 | Psicología | D33 | ¿En qué circunstancias se dice que un hallazgo psicológico posee validez ecológica? | Cuando sus resultados se mantienen en situaciones de la vida cotidiana y en contextos naturales. | L | R describe una circunstancia completa; revisar si puede formularse como respuesta cerrada. |
| 6 | Geografía | D03 | ¿Qué término geográfico designa la relación entre un lugar y la posición que ocupa respecto de otros lugares? | Situación geográfica | A | «Relación entre lugar y posición» admite otras expresiones; comprobar univocidad. |
| 7 | Gastronomía | D50 | ¿Qué término de la gastronomía francesa designa una preparación de champiñones finamente picados y cocinados, normalmente con mantequilla y chalota? | Duxelles. | — | — |
| 8 | Literatura | D13 | ¿En qué marco temporal se sitúa la acción de la novela El siglo de las luces, de Alejo Carpentier? | En las décadas posteriores a la Revolución francesa, entre finales del siglo XVIII y comienzos del XIX | L | R es un intervalo temporal abierto; comprobar precisión y cierre para distractores. |
| 9 | Informática | D30 | En un lenguaje de programación con alcance léxico, ¿cómo se denomina el ámbito dentro del cual un identificador puede utilizarse válidamente? | El alcance léxico | E | «Alcance léxico» aparece literalmente en el enunciado. |
| 10 | Biología | D79 | En biología molecular, ¿cómo se denomina la relación en la que la expresión de un gen queda inhibida por la acción de una proteína represora? | Regulación negativa | — | — |
| 11 | Derecho | D01 | ¿A qué entidad corresponde en España la potestad de juzgar y hacer ejecutar lo juzgado? | A los jueces y tribunales | S | «Jueces y tribunales» es conocimiento cívico directo; nivel 10 dudoso. |
| 12 | Música | D85 | ¿Qué recurso armónico media entre la tonalidad de partida y la tonalidad de llegada para hacer posible una modulación diatónica? | El acorde pivote | — | — |
| 13 | Literatura | D34 | ¿Cómo se denomina en literatura la representación escrita de los rasgos físicos externos de un personaje? | Prosopografía | — | — |
| 14 | Biología | D74 | ¿Qué relación de intervención establece la nucleasa Cas9 con el ADN diana durante la edición genética CRISPR-Cas9? | Cas9, guiada por un ARN, reconoce una secuencia de ADN adyacente a un motivo PAM y corta sus dos cadenas. | L | R describe todo un mecanismo de Cas9; no cabe fácilmente como alternativa breve. |
| 15 | Música | D34 | ¿Qué técnica compositiva renacentista representa musicalmente un texto utilizando sus vocales como base para obtener las notas de una melodía? | El soggetto cavato. | — | — |
| 16 | Historia | D72 | ¿Qué compilación jurídica de Justiniano desempeñó un papel decisivo en la recepción medieval del derecho romano en Europa? | El Corpus iuris civilis | — | — |
| 17 | Arquitectura | D27 | ¿Qué elemento arquitectónico exterior media en el control de la radiación solar que llega al interior de un edificio? | El brise-soleil o quiebrasol | — | — |
| 18 | Arte | D69 | ¿Qué performance de Marina Abramović, presentada en la galería Studio Morra de Nápoles en 1974, permitió al público utilizar sobre su cuerpo una serie de objetos dispuestos para la intervención? | Rhythm 0. | — | — |
| 19 | Arquitectura | D62 | ¿Qué tipo de dibujo arquitectónico media entre una afirmación sobre la relación vertical de los espacios y los elementos del edificio que permiten comprobarla? | La sección arquitectónica | T | «Media entre una afirmación» es una construcción metalingüística forzada. |
| 20 | Matemáticas | D13 | En teoría matemática de señales, ¿en qué semieje temporal puede ser distinta de cero una señal causal? | En el semieje t ≥ 0. | L | R es la definición temporal de causalidad; conviene verificar formato y opciones. |
| 21 | Informática | D76 | ¿En qué circunstancias un actuador interviene en una realidad externa dentro de un sistema informático o de control? | Cuando recibe una señal de control y la convierte en una acción física sobre el entorno. | L, T | La pregunta describe qué hace un actuador y R lo parafrasea en una frase. |
| 22 | Física | D18 | ¿En qué circunstancias se produce la radiación de Cherenkov? | Cuando una partícula cargada atraviesa un medio a una velocidad superior a la velocidad de fase de la luz en ese medio. | L | R es la condición definitoria de Cherenkov escrita en una frase larga. |
| 23 | Lingüística | D76 | ¿En qué contextos puede aparecer un pronombre átono pospuesto al verbo en español estándar? | Con un infinitivo, un gerundio o un imperativo afirmativo. | L | R exige una lista de tres casos: comprobar si es exhaustiva y distractores. |
| 24 | Geología | D30 | ¿Hasta qué profundidad aproximada se extiende el manto terrestre antes de comenzar el núcleo? | Unos 2.900 kilómetros | — | — |
| 25 | Economía | D85 | ¿Qué concepto económico permite valorar la conveniencia de una intervención comparando sus beneficios y sus costes, incluidos los efectos sobre otras alternativas? | El análisis coste-beneficio. | S, T | El enunciado prácticamente describe el análisis coste-beneficio; dificultad máxima dudosa. |
| 26 | Química | D10 | En la teoría de colisiones, ¿cómo se denomina el suceso microscópico en el que dos partículas colisionan con energía y orientación suficientes para producir una reacción química? | Una colisión eficaz | — | — |
| 27 | Música | D05 | ¿Cómo se denomina en teoría musical el intervalo formado por tres tonos enteros? | El tritono | — | — |
| 28 | Biología | D82 | ¿Qué técnica de edición genética utiliza una nucleasa guiada por ARN y cuya aplicación con Cas9 requiere que la secuencia diana se encuentre junto a un motivo PAM? | La edición genética mediante el sistema CRISPR-Cas9. | E | «CRISPR-Cas9» aparece en Q y en R; la identificación queda muy facilitada. |
| 29 | Filosofía | D63 | ¿En qué contexto filosófico se examina una afirmación mediante argumentos, razones y pruebas que pretenden justificarla? | En el contexto de justificación | E | «Justificarla» en Q conduce directamente a «contexto de justificación». |
| 30 | Filosofía | D42 | ¿Qué regla de inferencia permite pasar formalmente de «si P, entonces Q» y «P» a «Q»? | El modus ponens. | — | — |
| 31 | Historia | D24 | ¿Qué órgano de la monarquía hispánica desempeñaba la función de asesorar al rey y administrar justicia en los asuntos de los territorios americanos? | El Consejo de Indias | — | — |
| 32 | Matemáticas | D60 | En lógica matemática, ¿cómo se denomina el elemento cuya existencia demuestra que una proposición existencial es verdadera? | Un testigo | — | — |
| 33 | Literatura | D44 | ¿Cómo denomina Gérard Genette al texto anterior que sirve de base o fuente de transformación para otro texto, llamado hipertexto? | Hipotexto. | — | — |
| 34 | Economía | D61 | ¿Cómo se denomina en economía el vínculo mediante el cual una hipótesis se evalúa con datos observados? | La contrastación empírica | A | «Vínculo» no selecciona inequívocamente «contrastación empírica». |
| 35 | Filosofía | D21 | ¿Qué relación filosófica expresa que no puede haber una diferencia en ciertos hechos o propiedades sin una diferencia correspondiente en las condiciones que los sustentan? | La superveniencia | — | — |
| 36 | Lingüística | D08 | ¿Qué término lingüístico designa el elemento que vincula participantes y determina la configuración relativa de una relación sintáctica entre ellos? | El relator | A, T | «El relator» requiere verificar terminología canónica y univocidad; Q forzada. |
| 37 | Lingüística | D82 | En la teoría de los actos de habla, ¿cómo se denomina una intervención que solo puede realizar eficazmente quien posee la autoridad adecuada y dentro del procedimiento y contexto pertinentes, como declarar legalmente casada a una pareja? | Un acto de habla declarativo. | — | — |
| 38 | Geología | D58 | En geología, ¿bajo qué supuesto se sostiene el principio del actualismo? | Que los procesos y leyes naturales observables en el presente también explican la formación de estructuras geológicas del pasado | L | R es una formulación explicativa completa del principio de actualismo. |
| 39 | Medicina | D73 | En farmacología, ¿cómo se denomina la estructura biológica externa a un fármaco a la que este se une para desencadenar un efecto? | El receptor farmacológico. | S | La descripción del «receptor» farmacológico resulta demasiado guiada. |
| 40 | Filosofía | D63 | ¿En qué circunstancias se considera que una afirmación posee justificación a priori? | Cuando puede justificarse mediante la razón, sin depender de la experiencia empírica | S, L | Q ya nombra «justificación a priori»; R la define y no exige recuperar un dato. |
| 41 | Arquitectura | D81 | ¿En qué circunstancias depende la estabilidad de una bóveda de fábrica de la colocación de tirantes metálicos? | Cuando la bóveda genera empujes horizontales que los muros o contrafuertes no pueden absorber por sí solos y los tirantes deben contenerlos. | L | R combina varias condiciones constructivas; respuesta difícil de cerrar. |
| 42 | Sociología | D02 | ¿Qué característica corresponde a la solidaridad orgánica descrita por Émile Durkheim? | La interdependencia entre individuos derivada de la división social del trabajo | S, L | La solidaridad orgánica queda definida por sus rasgos; respuesta larga y nivel máximo dudoso. |
| 43 | Literatura | D03 | En la épica homérica, ¿cómo se denomina la relación retórica por la que un personaje queda asociado de forma fija a un rasgo, como Aquiles a «el de los pies ligeros»? | Epíteto formular | — | — |
| 44 | Arte | D14 | ¿Qué se intenta establecer en una obra de arte cuando se determina quién fue su creador? | La autoría | E | «Determinar quién fue su creador» ya expresa «autoría»; trivial. |
| 45 | Informática | D35 | ¿Qué carácter corresponde al punto de código Unicode U+03B6? | La letra griega minúscula zeta (ζ) | — | — |
| 46 | Sociología | D52 | ¿Qué concepto sociológico y semiológico designa el sistema de convenciones que media entre aquello que una comunidad representa y los signos con los que lo representa? | Código | A, T | «Código» es demasiado genérico para Q; texto artificioso. |
| 47 | Historia | D71 | ¿Qué enfoque historiográfico sostiene que una intervención política debe interpretarse según la coyuntura lingüística e histórica en la que fue formulada? | El contextualismo histórico | — | — |
| 48 | Arte | D83 | Según la teoría institucional del arte, ¿de qué depende que un objeto o una intervención pueda ser reconocido como obra de arte? | De su reconocimiento dentro del mundo del arte, es decir, del contexto institucional y de las prácticas de artistas, críticos, museos y otras instituciones artísticas | A, L | R es una explicación institucional extensa y circular; su límite no está bien fijado. |
| 49 | Historia | D56 | ¿Cómo denomina Hayden White la operación mediante la cual el historiador organiza acontecimientos en una trama narrativa para dotarlos de significado? | Emplotment | — | — |
| 50 | Arquitectura | D16 | ¿De qué antecedente constructivo procede el arbotante gótico? | De la exteriorización del contrafuerte, que pasó a transmitir al exterior los empujes de las bóvedas. | L, T | R es una explicación constructiva discutible como respuesta corta; Q forzada. |

### Sin D, sin U

| Llamada | P | D | Q10 (literal) | R10 (literal) | Señales | Motivo |
|---:|---|---|---|---|---|---|
| 1 | Arte | — | ¿Cómo se denomina la técnica artística que representa una imagen distorsionada que solo se reconoce al observarla desde un ángulo determinado? | Anamorfosis | — | — |
| 2 | Derecho | — | ¿Qué principio jurídico establece que nadie puede ser castigado por una conducta que no estuviera tipificada como delito antes de cometerse? | El principio de legalidad penal | S | El principio de legalidad penal es un concepto jurídico relativamente básico; calibrar nivel 10. |
| 3 | Química | — | ¿Qué elemento químico tiene el número atómico 117 y el símbolo Ts? | Teneso | — | — |
| 4 | Arquitectura | — | ¿Quién diseñó la iglesia de San Carlo alle Quattro Fontane, en Roma? | Francesco Borromini | — | — |
| 5 | Psicología | — | ¿Cómo se denomina la incapacidad neurológica para reconocer rostros familiares, incluso cuando la visión permanece intacta? | Prosopagnosia | — | — |
| 6 | Geografía | — | ¿Qué ciudad es la capital de Palaos? | Ngerulmud | — | — |
| 7 | Gastronomía | — | ¿Cómo se llamaba la salsa de pescado fermentado utilizada ampliamente en la gastronomía de la antigua Roma? | Garum | — | — |
| 8 | Literatura | — | ¿Quién escribió la novela experimental «La vida instrucciones de uso»? | Georges Perec | — | — |
| 9 | Informática | — | ¿Cómo se denomina la estructura de datos especializada en almacenar cadenas y realizar búsquedas eficientes por prefijos? | Trie (árbol de prefijos) | — | — |
| 10 | Biología | — | ¿Qué enzima cataliza la fijación del dióxido de carbono en el ciclo de Calvin? | RuBisCO | — | — |
| 11 | Derecho | — | ¿Qué principio jurídico establece que nadie puede ser sancionado por un hecho que no estuviera previamente definido como infracción por la ley? | El principio de legalidad sancionadora | S | La legalidad sancionadora es una noción general; comprobar dificultad real. |
| 12 | Música | — | ¿Qué compositor francés compuso la Turangalîla-Symphonie? | Olivier Messiaen | — | — |
| 13 | Literatura | — | ¿Quién escribió la novela La conciencia de Zeno? | Italo Svevo | — | — |
| 14 | Biología | — | ¿Qué enzima cataliza la fijación del dióxido de carbono en el ciclo de Calvin? | La ribulosa-1,5-bisfosfato carboxilasa/oxigenasa (RuBisCO) | R | Mismo hecho que en la llamada 10: enzima RuBisCO. |
| 15 | Música | — | ¿Qué compositor francés compuso la Sinfonía Turangalila? | Olivier Messiaen | R | Mismo autor y obra que en la llamada 12: Messiaen y Turangalîla. |
| 16 | Historia | — | ¿Qué tratado de 1559 puso fin a las guerras italianas entre España y Francia? | Tratado de Cateau-Cambrésis | — | — |
| 17 | Arquitectura | — | ¿Qué arquitecto barroco diseñó la iglesia de San Carlo alle Quattro Fontane en Roma? | Francesco Borromini | R | Mismo hecho que en la llamada 4: Borromini y San Carlo. |
| 18 | Arte | — | ¿Qué pintor flamenco realizó el Políptico de Gante, también conocido como La adoración del Cordero Místico? | Jan van Eyck | — | — |
| 19 | Arquitectura | — | ¿Qué arquitecto diseñó el Cementerio de San Cataldo, en Módena, Italia? | Aldo Rossi | — | — |
| 20 | Matemáticas | — | ¿Cuál es el menor número entero positivo que puede expresarse como suma de dos cubos positivos de dos maneras distintas? | 1729. | — | — |
| 21 | Informática | — | ¿Qué estructura de datos autoequilibrada utiliza nodos cuyos enlaces pueden ser de color rojo o negro? | Árbol rojo-negro | E | «Rojo o negro» aparece en Q y entrega el nombre «árbol rojo-negro». |
| 22 | Física | — | ¿Qué teorema de la física relaciona cada simetría continua diferenciable de un sistema con una ley de conservación? | El teorema de Noether | — | — |
| 23 | Lingüística | — | ¿Cómo se denomina en lingüística la supresión de una de dos sílabas contiguas semejantes o idénticas? | Haplología | — | — |
| 24 | Geología | — | ¿Cómo se llama la discontinuidad sísmica que separa la corteza terrestre del manto? | La discontinuidad de Mohorovičić | — | — |
| 25 | Economía | — | ¿Cómo se denomina en economía un bien cuya demanda aumenta cuando sube su precio, contradiciendo la ley habitual de la demanda? | Bien de Giffen | — | — |
| 26 | Química | — | ¿Qué nombre recibe el elemento químico de número atómico 113? | Nihonio | — | — |
| 27 | Música | — | ¿Qué compositor francés escribió la obra Turangalîla-Symphonie? | Olivier Messiaen | R | Mismo autor y obra que en las llamadas 12 y 15. |
| 28 | Biología | — | ¿Qué enzima cataliza la fijación del dióxido de carbono sobre la ribulosa-1,5-bisfosfato en el ciclo de Calvin? | La ribulosa-1,5-bisfosfato carboxilasa/oxigenasa (RuBisCO) | R | Mismo hecho que en las llamadas 10 y 14: RuBisCO. |
| 29 | Filosofía | — | ¿Qué filósofo medieval formuló el concepto de haecceidad, entendido como aquello que hace que un individuo sea este individuo concreto? | Juan Duns Escoto | — | — |
| 30 | Filosofía | — | ¿Qué filósofo desarrolló la fenomenología trascendental? | Edmund Husserl | — | — |
| 31 | Historia | — | ¿Qué paz de 1648 puso fin convencionalmente a la guerra de los Treinta Años? | La Paz de Westfalia | S | La Paz de Westfalia de 1648 es un dato histórico muy difundido; nivel 10 dudoso. |
| 32 | Matemáticas | — | ¿Cuál es el valor de la serie infinita 1 + 1/4 + 1/9 + 1/16 + ⋯? | π²/6 | — | — |
| 33 | Literatura | — | ¿Quién escribió la obra literaria del siglo XVII titulada The Anatomy of Melancholy? | Robert Burton | — | — |
| 34 | Economía | — | ¿Cómo se denomina en economía la crítica de que las predicciones basadas en relaciones históricas pueden fallar porque los agentes modifican su conducta cuando cambian las políticas? | Crítica de Lucas | — | — |
| 35 | Filosofía | — | ¿Qué término empleó Edmund Husserl para designar la suspensión del juicio sobre la existencia del mundo en la reducción fenomenológica? | Epoché fenomenológica | — | — |
| 36 | Lingüística | — | ¿Cómo se denomina el tipo de alineamiento lingüístico en el que el sujeto de un verbo intransitivo recibe el mismo tratamiento que el objeto de un verbo transitivo? | Alineamiento ergativo-absolutivo | — | — |
| 37 | Lingüística | — | ¿Qué término de la lingüística histórica designa una lengua cuyo parentesco genealógico con cualquier otra lengua conocida no ha podido demostrarse? | Lengua aislada | — | — |
| 38 | Geología | — | ¿Qué discontinuidad sísmica separa la corteza terrestre del manto? | Discontinuidad de Mohorovičić | R | Mismo hecho que en la llamada 24: discontinuidad de Mohorovičić. |
| 39 | Medicina | — | ¿Cómo se denomina el síndrome causado por la presencia de una copia adicional del cromosoma 18? | Síndrome de Edwards | — | — |
| 40 | Filosofía | — | ¿Qué término empleó Martin Heidegger para designar la existencia humana entendida como «ser-en-el-mundo»? | Dasein | — | — |
| 41 | Arquitectura | — | ¿Qué arquitecto diseñó la iglesia de San Carlo alle Quattro Fontane, en Roma? | Francesco Borromini | R | Mismo hecho que en las llamadas 4 y 17: Borromini y San Carlo. |
| 42 | Sociología | — | ¿Qué concepto sociológico desarrolló Émile Durkheim para describir la ausencia o debilitamiento de normas sociales que regulan la conducta? | La anomia | — | — |
| 43 | Literatura | — | ¿Qué escritor francés publicó la novela La vida instrucciones de uso? | Georges Perec | R | Mismo hecho que en la llamada 8: Perec y La vida instrucciones de uso. |
| 44 | Arte | — | ¿Qué pintor italiano del Renacimiento realizó el ciclo de frescos sobre la leyenda de la Vera Cruz en la basílica de San Francisco de Arezzo? | Piero della Francesca | — | — |
| 45 | Informática | — | ¿Qué algoritmo permite hallar los caminos mínimos desde un vértice en un grafo dirigido, incluso cuando existen aristas con pesos negativos, siempre que no haya ciclos negativos alcanzables? | Algoritmo de Bellman-Ford | — | — |
| 46 | Sociología | — | ¿Qué término designa, en la sociología de la ciencia, la tendencia a que los investigadores ya reconocidos reciban una cantidad desproporcionada de crédito y recursos? | El efecto Mateo | — | — |
| 47 | Historia | — | ¿Qué tratado de 1774 puso fin a la guerra ruso-turca de 1768-1774 y otorgó a Rusia importantes ventajas sobre el Imperio otomano? | El Tratado de Küçük Kaynarca | — | — |
| 48 | Arte | — | ¿Qué pintor flamenco del siglo XV realizó el Tríptico de Portinari? | Hugo van der Goes | — | — |
| 49 | Historia | — | ¿En qué año se firmó el Tratado de Tordesillas entre Castilla y Portugal? | 1494 | S | 1494, fecha del Tratado de Tordesillas, es dato escolar habitual en España. |
| 50 | Arquitectura | — | ¿Qué arquitecto diseñó la iglesia de San Carlo alle Quattro Fontane en Roma? | Francesco Borromini | R | Mismo hecho que en las llamadas 4, 17 y 41: Borromini y San Carlo. |

### Sin D, con U

| Llamada | P | D | Q10 (literal) | R10 (literal) | Señales | Motivo |
|---:|---|---|---|---|---|---|
| 1 | Arte | — | ¿Qué pintor realizó la obra El entierro del conde de Orgaz? | El Greco | S | El Greco y El entierro del conde de Orgaz son muy conocidos; nivel 10 dudoso. |
| 2 | Derecho | — | ¿Qué principio jurídico latino impide volver a litigar un asunto que ya ha sido resuelto mediante sentencia firme? | Res judicata | — | — |
| 3 | Química | — | ¿Qué elemento químico tiene el símbolo Hf y el número atómico 72? | Hafnio | — | — |
| 4 | Arquitectura | — | ¿Qué arquitecto neerlandés diseñó la Casa Schröder, construida en Utrecht en 1924? | Gerrit Rietveld | — | — |
| 5 | Psicología | — | ¿Qué trastorno neuropsicológico consiste en creer que un lugar familiar ha sido duplicado o existe en dos sitios simultáneamente? | La paramnesia reduplicativa | — | — |
| 6 | Geografía | — | ¿Cuál es la capital de Bután? | Timbu | — | — |
| 7 | Gastronomía | — | ¿Cómo se denomina la sensación de plenitud y prolongación del sabor asociada a ciertos alimentos ricos en glutamatos y péptidos? | El kokumi | — | — |
| 8 | Literatura | — | ¿Qué escritor austríaco escribió la novela inacabada «El hombre sin atributos»? | Robert Musil | — | — |
| 9 | Informática | — | ¿Cómo se llama el algoritmo de consenso distribuido basado en un líder y un registro replicado, utilizado en sistemas informáticos tolerantes a fallos? | Raft | A | Líder + registro replicado puede describir más de un algoritmo; verificar univocidad de Raft. |
| 10 | Biología | — | ¿Cómo se denomina el complejo molecular que elimina intrones del pre-ARNm mediante corte y empalme? | El espliceosoma | — | — |
| 11 | Derecho | — | ¿Qué tratado internacional creó la Corte Penal Internacional? | El Estatuto de Roma | S | El Estatuto de Roma es conocimiento general de instituciones internacionales; calibrar nivel 10. |
| 12 | Música | — | ¿Qué compositor austríaco compuso la ópera Wozzeck? | Alban Berg | — | — |
| 13 | Literatura | — | ¿Qué heterónimo de Fernando Pessoa escribió la «Oda triunfal»? | Álvaro de Campos | — | — |
| 14 | Biología | — | ¿Qué gen supresor de tumores humano codifica la proteína p53? | TP53 | E | «p53» en Q revela casi literalmente el símbolo TP53 de R. |
| 15 | Música | — | ¿Qué compositor alemán creó la obra electrónica «Gesang der Jünglinge»? | Karlheinz Stockhausen | — | — |
| 16 | Historia | — | ¿Qué tratado de 1774 puso fin a la guerra ruso-turca de 1768-1774 y concedió importantes ventajas a Rusia? | El Tratado de Küçük Kaynarca | — | — |
| 17 | Arquitectura | — | ¿Qué arquitecto neerlandés diseñó la Casa Schröder en Utrecht? | Gerrit Rietveld | R | El mismo hecho Rietveld/Casa Schröder aparece en llamada 4; U se reinició entre bloques. |
| 18 | Arte | — | ¿Cómo se denomina la técnica artística que representa una imagen deformada para que se vea correctamente desde un punto de vista específico? | La anamorfosis | — | — |
| 19 | Arquitectura | — | ¿Qué arquitecto uruguayo diseñó la Iglesia de Cristo Obrero en Atlántida? | Eladio Dieste | — | — |
| 20 | Matemáticas | — | ¿Cómo se denomina el resultado de Gödel según el cual ciertos sistemas formales consistentes y suficientemente expresivos contienen proposiciones verdaderas que no pueden demostrar dentro del propio sistema? | El teorema de incompletitud de Gödel | H | «Gödel» aparece en Q y en R; pista fuerte, pero no da literalmente «incompletitud». |
| 21 | Informática | — | ¿Cómo se llama el algoritmo de consenso distribuido descrito por Leslie Lamport en un artículo de 1998? | Paxos | — | — |
| 22 | Física | — | ¿Qué bosón gauge media la interacción fuerte entre los quarks? | El gluón | S | «Gluón» es un concepto bastante conocido en divulgación de física; nivel 10 dudoso. |
| 23 | Lingüística | — | ¿Cómo se denomina en lingüística el sistema de alineamiento en el que el sujeto de un verbo intransitivo se trata gramaticalmente como el objeto de un verbo transitivo? | La ergatividad | — | — |
| 24 | Geología | — | ¿Cómo se denomina la discontinuidad sísmica que separa la corteza terrestre del manto? | La discontinuidad de Mohorovičić | — | — |
| 25 | Economía | — | ¿Qué concepto macroeconómico describe la combinación de inflación elevada, desempleo alto y estancamiento económico? | La estanflación | S | «Estanflación» es un concepto macroeconómico bastante conocido; nivel 10 dudoso. |
| 26 | Química | — | ¿Qué regla de la química orgánica establece que un sistema cíclico, plano y conjugado es aromático si posee 4n+2 electrones pi? | La regla de Hückel | — | — |
| 27 | Música | — | ¿Qué técnica de la música medieval consiste en repartir fragmentos melódicos entre distintas voces, produciendo una interrupción alternada del sonido? | El hoquetus | — | — |
| 28 | Biología | — | ¿Qué tipo de células gliales forman la vaina de mielina alrededor de los axones en el sistema nervioso periférico? | Las células de Schwann | — | — |
| 29 | Filosofía | — | ¿Cómo se denomina, en la fenomenología, la suspensión provisional de los juicios sobre la existencia del mundo para analizar la experiencia? | La epojé | — | — |
| 30 | Filosofía | — | ¿Qué postura filosófica sostiene que únicamente puede afirmarse con certeza la existencia de la propia mente y de sus experiencias? | El solipsismo | — | — |
| 31 | Historia | — | ¿Qué tratado de 1721 puso fin a la Gran Guerra del Norte entre Suecia y la coalición encabezada por Rusia? | El Tratado de Nystad | — | — |
| 32 | Matemáticas | — | ¿Cómo se denomina el teorema de Kurt Gödel que afirma que, en ciertos sistemas formales consistentes y suficientemente potentes, existen enunciados que no pueden demostrarse ni refutarse dentro del propio sistema? | Primer teorema de incompletitud de Gödel | H, R | Se repite el hecho de la llamada 20 (incompletitud de Gödel); Q revela el epónimo. |
| 33 | Literatura | — | ¿Quién escribió El relato de Genji, considerada una de las primeras novelas de la literatura mundial? | Murasaki Shikibu | — | — |
| 34 | Economía | — | ¿Cómo se denomina el fenómeno por el que una depreciación de la moneda puede empeorar inicialmente la balanza comercial antes de mejorarla? | Efecto curva J | — | — |
| 35 | Filosofía | — | ¿Cómo se denomina el argumento expuesto en el diálogo Parménides de Platón que plantea una regresión infinita de las formas? | El argumento del tercer hombre | — | — |
| 36 | Lingüística | — | ¿Cómo se denomina el tipo de alineamiento sintáctico en el que el sujeto de un verbo intransitivo se trata como el objeto de un verbo transitivo? | Alineamiento ergativo-absolutivo | R | Mismo concepto de la llamada 23: ergatividad / alineamiento ergativo; bloques distintos. |
| 37 | Lingüística | — | ¿Cómo se denominan las consonantes reconstruidas por la lingüística histórica para el protoindoeuropeo y representadas tradicionalmente como h₁, h₂ y h₃? | Laringales | — | — |
| 38 | Geología | — | ¿Cómo se denomina la discontinuidad geológica que separa la corteza continental superior de la inferior? | Discontinuidad de Conrad | — | — |
| 39 | Medicina | — | ¿Qué canalopatía hereditaria puede provocar arritmias ventriculares y se asocia principalmente con alteraciones del segmento ST en las derivaciones precordiales derechas? | Síndrome de Brugada | — | — |
| 40 | Filosofía | — | ¿Qué problema filosófico planteó Edmund Gettier contra la definición tradicional del conocimiento como creencia verdadera justificada? | Problema de Gettier | E | «Edmund Gettier» figura en Q y «Problema de Gettier» en R. |
| 41 | Arquitectura | — | ¿Qué arquitecto neerlandés diseñó la Casa Schröder, construida en Utrecht en 1924? | Gerrit Rietveld | R | El hecho Rietveld/Casa Schröder ya estaba en las llamadas 4 y 17; bloques distintos. |
| 42 | Sociología | — | ¿Qué concepto de Émile Durkheim describe la cohesión social basada en la semejanza entre los miembros de una sociedad? | Solidaridad mecánica | S | La solidaridad mecánica es un concepto introductorio de sociología; calibrar nivel 10. |
| 43 | Literatura | — | ¿Qué novela de Witold Gombrowicz está narrada por un escritor polaco que viaja en barco hacia Buenos Aires y queda atrapado en una intriga de identidades? | Transatlántico | — | — |
| 44 | Arte | — | ¿Cómo se denomina la técnica pictórica barroca que crea la ilusión de una arquitectura abierta mediante una perspectiva fingida? | La quadratura | — | — |
| 45 | Informática | — | ¿Qué algoritmo de consenso tolerante a fallos bizantinos fue desarrollado por Miguel Castro y Barbara Liskov? | Practical Byzantine Fault Tolerance (PBFT) | — | — |
| 46 | Sociología | — | ¿Cómo se llama la teoría sociológica desarrollada por Anthony Giddens que integra la acción de los individuos y las estructuras sociales? | Teoría de la estructuración | — | — |
| 47 | Historia | — | ¿Cómo se denomina el conjunto de tratados firmado en 1713 que puso fin a gran parte de la guerra de sucesión española? | Tratado de Utrecht | S | El Tratado de Utrecht de 1713 es conocimiento histórico escolar bastante habitual en España. |
| 48 | Arte | — | ¿Cómo se denomina el movimiento artístico italiano surgido a finales de la década de 1970, asociado a artistas como Sandro Chia y Francesco Clemente? | La transvanguardia | — | — |
| 49 | Historia | — | ¿Qué acuerdo de 1122 puso fin a la Querella de las Investiduras entre el papa Calixto II y el emperador Enrique V? | Concordato de Worms | — | — |
| 50 | Arquitectura | — | ¿Qué arquitecto italiano diseñó la Casa del Fascio en Como? | Giuseppe Terragni | — | — |

## Interpretación

La comparación describe **tipos de problemas observados**, no un orden de superioridad entre modos ni una estimación estadística de la dificultad real. En esta muestra, las respuestas no cerradas y la redacción subordinada a D están más presentes entre las preguntas 10 del experimento con D; en los modos sin D destacan algunas preguntas introductoras, respuestas filtradas y repetición entre llamadas/bloques. Los recuentos dependen de la taxonomía y de una revisión cualitativa; deben revisarse contra Terra y, cuando corresponda, con respuestas de jugadores.
