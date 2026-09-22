# Quiz10 Web: Random/Test

## Preparación

El formulario inicial envía `POST /games` con `name` y `selection` (`__RANDOM__`
o la etiqueta de un área). `StandardCoveragePlanner` fija diez áreas y dificultades;
`createQuizPreparer` conecta estas dos operaciones:

1. `TerraCoverageRouteGenerator.generate(plan)` genera diez conocimientos con
   `TerraCoveragePrompt` y el esquema `quiz10_coverage_route_from_plan`.
2. `TerraCoverageQuestionReviewer.review(route)` valida y genera las diez preguntas
   con `TerraCoverageRouteValidationPrompt` y el esquema
   `quiz10_coverage_question_review`.

En la segunda respuesta, `valid=true` conserva la respuesta de la ruta y deja
`issue` vacío; `valid=false` incluye el motivo y una pregunta de sustitución
completa. El procesamiento comprueba diez filas, respuestas conservadas,
distractores y enunciados no duplicados. `CoverageQuestionCompleter` incorpora las
sustituciones de esa respuesta sin llamar a IA. Una fila incompleta o inconsistente
hace fallar la preparación con `CoverageQuestionCompletionError.UnresolvedPositions`,
que identifica las posiciones sin pregunta válida detectadas por el completador.
No hay generador independiente ni reintentos de sustitución. La auditoría conserva el motivo original y la aceptación de la sustitución.

`Quiz10Flow` presenta las diez preguntas ya preparadas, incluida la primera, sin
llamadas a Luna. La sobrecarga de preparación por tema y su validador pertenecen
al recorrido por tema; el formulario web utiliza la sobrecarga por plan.

## Ejecución y comprobaciones

La configuración se obtiene de las variables `AI_APPS_ENV`, `AI_APPS_AI_BASE_URL`,
`AI_APPS_AI_API_KEY` y `AI_APPS_AI_{TERRA,LUNA,MINI}_MODEL`.

```bash
./gradlew :apps:quiz10-web:build :systems:games:quiz10:test \
  :core:ai:test :core:network:test :ui:quiz10-web:test
./gradlew :apps:quiz10-web:run
```

El puerto predeterminado es 8080; `QUIZ10_WEB_PORT` permite usar otro sin interrumpir
sesiones existentes. La página inicial responde a `GET /`.

Las pruebas ordinarias usan respuestas controladas. `RandomTestPreparationTest`
recorre por HTTP las diez preguntas con y sin sustitución, comprueba exactamente
dos llamadas TERRA y rechaza una sustitución incompleta sin una tercera llamada.
La prueba real es optativa, requiere credenciales y debe coordinarse con el usuario:

```bash
QUIZ10_REAL_PREPARATION=1 ./gradlew :apps:quiz10-web:test \
  --tests '*RandomTestPreparationTest.realPreparationProducesTenPlayableQuestionsWithOnlyTwoTerraCalls' \
  --rerun-tasks
```

Esta prueba real ejecuta los dos generadores y reproduce los diez turnos con el
cliente y los límites de producción. No se activa durante la compilación habitual.

## Latencia y diagnóstico

El cliente envía una petición JSON no streaming a `/v1/responses` con `model`,
`input` y `text.format` (`json_schema`, `strict=true`). No establece
`reasoning.effort`: se utiliza el valor predeterminado del modelo configurado.
Los límites siguen siendo 5 segundos de conexión y 30 segundos de lectura.
El tiempo de preparación incluye ambas llamadas secuenciales.

Los registros de [MONIT-AI](../../tools/monit-ai/README.md) identifican modelo,
operación, duración, resultado y partida; no contienen prompts ni credenciales.
`AI_APPS_USAGE_FILE` permite aislar los registros de una prueba. Un error de lectura
no demuestra por sí solo un problema de DNS, modelo o prompt: hay que contrastarlo
con los tiempos de conexión, primer byte y procesamiento del servicio.

Abrir la página inicial o compilar no verifica la preparación real. Tampoco una
partida exitosa garantiza una latencia estable por debajo del límite de lectura.

## Diagnóstico del 22 de septiembre de 2026

Configuración observada tanto en el entorno como en el proceso web:
`gpt-5.6-terra`, `https://api.openai.com/v1/responses`, sin proxy configurado.
El fallo histórico y otro reproducido en el servidor corregido registraron
`READ_TIMEOUT` a los 30.342 y 30.341 ms. El transporte ya estaba en la fase de
recepción; no se había llegado a procesar la ruta. No se dispone de una respuesta
ni del tiempo de procesamiento del proveedor para esas solicitudes abortadas,
por lo que no puede demostrarse el origen interno de su demora.

Una comprobación independiente de conectividad completó DNS/TCP/TLS en unos
44 ms y recibió el HTTP 401 esperado sin autenticación. En la comparación
controlada de TERRA 1 (plan de Historia, mismo prompt y esquema UTF-8), el modo
predeterminado respondió en 12,193 s y `reasoning.effort=low` en 17,152 s.
Los encabezados `openai-processing-ms` indicaron 11.935 y 16.748 ms: en esas
solicitudes casi toda la espera correspondió al procesamiento remoto. Las
respuestas confirmaron `medium` y `low`, respectivamente. Esto no demuestra que
`low` mejore la latencia y no se incorporó ese cambio. El valor predeterminado
`medium` está documentado en la [ficha oficial del modelo](https://developers.openai.com/api/docs/models/gpt-5.6-terra).

Además del timeout se reprodujo un fallo independiente: TERRA 2 devolvió una fila
marcada como válida con una respuesta distinta de la ruta. El prompt activo había
perdido la instrucción de conservar esa respuesta y el encabezado de la tabla.
Se corrigieron ambos, se explicitó el contrato JSON de las sustituciones y se
recuperó la auditoría de su motivo. Las pruebas obsoletas que dependían del
generador eliminado se sustituyeron por pruebas del procesamiento en dos llamadas.

Resultados finales:

- Build web y suites de web, sistema, IA, red y UI: 179 pruebas, 175 ejecutadas,
  cuatro pruebas reales omitidas por defecto, cero fallos.
- Prueba real optativa de preparación: ejecutada aparte, diez preguntas jugables,
  exactamente dos llamadas TERRA, 42.360 ms de preparación.
- Servidor corregido arrancado en 8082: página inicial HTTP 200. Tras un intento
  con timeout, una nueva partida llegó a la primera pregunta y completó las diez
  respuestas por HTTP hasta la pantalla de resultado.
- Esa partida registró cobertura en 16.389 ms y revisión en 14.510 ms;
  preparación total 30.923 ms. Dos llamadas TERRA, cero llamadas Luna o de
  sustituciones; evento final `quiz10_game_completed`.
- Las sustituciones dentro de TERRA 2 se comprobaron con respuestas controladas;
  la partida real exitosa no necesitó sustituciones.
- `git diff --check` sin incidencias. El servidor existente de 8080 no se reinició.

La latencia de inicio sigue pendiente: se verificó el recorrido funcional real,
pero también se reprodujo el timeout y no se obtuvo un arranque en pocos segundos.
No se aumentó el timeout, no se añadieron reintentos ni una tercera llamada.
