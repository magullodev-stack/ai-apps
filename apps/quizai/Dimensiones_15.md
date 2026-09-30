# Dimensiones_15 — banco candidato de Quiz10

Quince definiciones **literales** del catálogo de `lib/coverage/factual_question_dimensions.dart`. Candidatas; ninguna se declara validada.

| D | Familia | Definición original | Vigilancia experimental |
|---|---|---|---|
| D01 | I01 | Pregunta por la entidad a la que corresponde una caracterización determinada. | En una auditoría anterior produjo Q10 demasiado fácil: contrastar dificultad efectiva. |
| D02 | I01 | Pregunta por la característica que corresponde a una entidad determinada. | Posibles respuestas descriptivas; revisar cierre de R. |
| D05 | I02 | Pregunta por una entidad a partir de su configuración respecto de otras. | Sin alerta específica previa. |
| D06 | I02 | Pregunta por otra entidad que participa en una configuración conjunta. | 2/30 objeciones sobre la definición. |
| D10 | I03 | Pregunta por el hecho que ocupa una posición temporal determinada. | Sin alerta específica previa. |
| D13 | I03 | Pregunta por el marco temporal en el que se sitúa un hecho. | Posibles periodos temporales poco delimitados. |
| D15 | I04 | Pregunta por el antecedente del que procede una entidad o estado. | Sin alerta específica previa. |
| D24 | I06 | Pregunta por el elemento que desempeña una función determinada. | Sin alerta específica previa. |
| D34 | I08 | Pregunta por una representación a partir de aquello que representa. | Comparar diversidad de hechos con D50 (representación convencional). |
| D35 | I08 | Pregunta por aquello que corresponde a una representación determinada. | Comparar diversidad de hechos con D49 (representación convencional). |
| D45 | M01 | Pregunta por la persona o entidad a la que se atribuye la procedencia de una entidad o contenido. | 1/30 objeciones sobre la definición. |
| D49 | M02 | Pregunta por aquello representado mediante una representación convencional. | Comparar diversidad de hechos con D35 (sin requisito de convencionalidad). |
| D50 | M02 | Pregunta por la representación convencional que corresponde a aquello representado. | Comparar diversidad de hechos con D34 (sin requisito de convencionalidad). |
| D69 | E01 | Pregunta por la intervención que tiene lugar en una situación determinada. | Sin alerta específica previa. |
| D78 | E03 | Pregunta por aquello que depende de una intervención determinada. | Posibles consecuencias múltiples; comprobar unicidad de R. |

## Evidencia previa

En `resultado-auditoria-D-30.md`, 13 de estas 15 dimensiones obtuvieron 0 objeciones en 30 evaluaciones de sus definiciones; D06 obtuvo 2 y D45 obtuvo 1. No son tasas de éxito de generación de preguntas.

## Comparación controlada de 200 llamadas por banco

- Brazos: D15 y D86, con 200 llamadas cada uno.
- Constantes: modelo, semilla, pivote por fila, niveles de dificultad 4/3/2/1, prompt experimental y esquema de salida. Sin U.
- Se sustituye solamente el banco de D. P por fila coincide entre brazos para cada llamada.
- D15: selección sin reemplazo por llamada, equilibrada por posición: cada D aparece 13 o 14 veces en cada fila al completar 200 llamadas.
- D86: selección sin reemplazo del catálogo original (aleatoria, sin equilibrio forzado).
- Medir dificultad efectiva y validez factual de Q10, univocidad, repeticiones semánticas y diferencias reales entre D34/D50 y D35/D49; vigilar D01, D02, D13 y D78.
- El prompt experimental usa: selección de R antes de Q, tres desigualdades estrictas entre bloques, 4–24 palabras en Q, 1–8 en R y prohibición de revelar R. No altera el prompt de producción.
- Los JSONL registran el prompt, el banco y las diez D utilizadas en cada llamada; resultados separados y guardados incrementalmente.

## Comandos (desde la raíz del repositorio)

```powershell
.\apps\quizai\run.ps1 -ProbarLuna -BancoD 15 -Muestras 200 -LunaSemilla 20260929
.\apps\quizai\run.ps1 -ProbarLuna -BancoD 86 -Muestras 200 -LunaSemilla 20260929
```

Cada comando realiza 200 llamadas reales (hasta 2.000 Q/R), con consumo de API. Los informes se guardan en `.ai-apps/experimentos-luna-pd/luna-banco-d15-*.jsonl` / `.md` y `luna-banco-d86-*.jsonl` / `.md`. Si se interrumpe, las llamadas completadas permanecen en JSONL; cada ejecución comienza en la primera semilla indicada.
