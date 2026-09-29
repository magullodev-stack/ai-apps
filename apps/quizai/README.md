# QuizAI

Aplicación con la modalidad estándar 🎲 Quiz10: diez preguntas de cultura general generadas mediante IA.

En la modalidad 🎲 se eligen diez áreas distintas y las preguntas siguen esta progresión: cuatro fáciles, tres moderadas, dos difíciles y una muy difícil. Cada pregunta tiene cuatro opciones; cada acierto suma un punto. Al finalizar se muestra el resultado sobre diez.

## Identidad visual de QuizAI

La pantalla principal utiliza una identidad propia de videojuego móvil:
fondo morado degradado, cabecera destacada, tarjetas de colores, bordes
redondeados, sombras y navegación inferior integrada.

Quiz10 es la modalidad protagonista y conserva su acceso directo a la
partida existente. Sala, 1vs1 y Estudio mantienen su estado no disponible.

Los indicadores de puntos, racha y ranking mostrarán sus datos cuando
existan los sistemas responsables de proporcionar sus datos reales.

La cabecera incorpora el logotipo propio de QuizAI, registrado como
recurso gráfico de la aplicación en `assets/branding/`.

La tipografía Nunito forma parte de la identidad visual de QuizAI.

La fuente variable se incorpora localmente en `assets/fonts/` y se
registra en `pubspec.yaml`. Se utiliza bajo la SIL Open Font License,
cuya copia se conserva en `assets/fonts/OFL.txt`.

La familia tipográfica y los estilos generales se configuran en
`lib/app/app_theme.dart`. Las pantallas de la aplicación y sus modalidades
utilizan el tema común, conservando sus responsabilidades particulares.

La navegación inferior utiliza explícitamente la misma familia.

La barra inferior de QuizAI utiliza una cápsula morada con dos pestañas
de igual anchura. La pestaña seleccionada ocupa su mitad mediante una
superficie clara, mientras que la pestaña inactiva conserva el fondo
morado. Los colores pertenecen a `lib/app/app_theme.dart` y el componente
de navegación pertenece a `lib/app/app_shell.dart`.

La navegación mantiene las pestañas Modalidades y Perfil, conserva la
selección al volver desde Configuración y permanece fija durante el
desplazamiento de la pantalla principal.
Los estilos particulares existentes siguen utilizando sus tamaños
y pesos hasta que se complete el rediseño de cada pantalla.

La pantalla principal utiliza cuatro PNG propios en assets/modalidades/.
Los textos y las acciones permanecen implementados en Flutter.

Los colores pertenecen a `lib/app/app_theme.dart`. La estructura general
y la navegación pertenecen a `lib/app/app_shell.dart`. Las tarjetas y la
pantalla de modalidades pertenecen a `lib/app/home/`.

El diseño se adapta al ancho disponible y permite desplazamiento vertical
cuando la altura del dispositivo no permite mostrar todas las modalidades.

## Navegación

La cabecera muestra **QuizAI** y el acceso a **Configuración**. La barra inferior fija alterna entre **Modalidades** y **Perfil**. Modalidades muestra directamente, en este orden, **🎲 Quiz10**, **🏆 Sala**, **⚔️ 1vs1** y **📚 Estudio**. Solo Quiz10 está disponible: al pulsarlo comienza la generación de la partida existente; la flecha de regreso vuelve a la pantalla principal. Salir de la modalidad descarta su partida en memoria.

Perfil y Configuración muestran únicamente un estado provisional, sin funciones ni datos de usuario. Desde Configuración se puede volver a la pestaña de origen.

`lib/main.dart` arranca QuizAI. `lib/app/` contiene la identidad, el tema, la navegación general y las pantallas Modalidades, Perfil y Configuración. `lib/modes/quiz10/` contiene exclusivamente la pantalla, el estado, las reglas, la validación y la generación mediante IA de la modalidad 🎲 Quiz10. Las pruebas se organizan en `test/app/` y `test/modes/quiz10/`. Las otras tres modalidades todavía no tienen implementación propia.

## Ejecutar con IA

Con `emulator-5554` iniciado, desde la raíz del repositorio en PowerShell:

```powershell
.\apps\quizai\run.ps1
```

El procedimiento inicia o reutiliza el servicio Dart, conecta el emulador y abre QuizAI con la configuración de desarrollo de `gpt-4.1-mini`. Busca la clave OpenAI en el entorno y, si falta, la solicita con entrada oculta. No es necesario introducir un token; la clave no se incluye en Flutter ni en el APK. La tarea manual de VS Code **AI-APPS: ejecutar QuizAI con IA** usa este mismo procedimiento. Cambiar de pestaña o abrir Configuración no llama al modelo; pulsar 🎲 Quiz10 sí solicita una generación.

La generación usa el Dart incluido en Flutter. El proyecto Android conserva su compilación independiente. El prompt y las reglas siguen en Quiz10; el esquema no envía `minItems` ni `maxItems` y el validador sigue exigiendo diez preguntas.

Consulta [`ai/README.md`](../../ai/README.md) para las variables, diagnósticos, seguridad y ciclo de vida del servicio. El registro está en `.ai-apps/dart-service.log`; `scripts/run-android.ps1 -StopService` detiene el servicio local. En Flutter, `r` aplica Hot Reload, `R` reinicia la partida y `q` cierra la sesión.

## Comprobaciones

Desde `apps/quizai`:

```powershell
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

Las pruebas automatizadas cubren también la identidad, el orden y disponibilidad de las modalidades, el cambio de pestañas, Configuración y el regreso desde Quiz10. Las pruebas del generador, validador, partida y conexión al servicio utilizan un proveedor simulado. El APK se genera en `build/app/outputs/flutter-apk/app-debug.apk`.

Para una generación real explícita, desde la raíz:

```powershell
.\apps\quizai\run.ps1 -VerifyOnly
```

La comprobación usa `gpt-4.1-mini` y solo tiene éxito si el validador de Quiz10 acepta diez preguntas. No modifica la sesión Android. El resultado sin contenido ni credenciales queda en `.ai-apps/quizai-verification.json`.

### Apertura automática desde AI-APPS

AI-APPS prepara el emulador compartido al abrir VS Code. Si
`.ai-apps/active-game.txt` contiene `quizai`, también ejecuta
`apps/quizai/run.ps1` automáticamente en la terminal integrada.

El lanzador de QuizAI conserva la preparación del servicio Dart de IA.
Si necesita una clave OpenAI, la solicita en la terminal.

Para trabajar sin abrir ningún juego, establecer `none` como juego
activo. El archivo de selección es local y no se publica en Git.

## Generación P × D → Q, R (Luna)

La primera operación definitiva de Quiz10 está implementada en
`lib/modes/quiz10/quiz10_luna.dart`. Dart dispone de dos bancos cerrados:
21 pivotes (`quiz10_pivots.dart`) y 86 instrucciones literales
«Pregunta por…» (`lib/coverage/factual_question_dimensions.dart`),
con sus 18 familias I/M/E. Cada partida sortea diez P distintas y diez D
distintas, sin reemplazo; asigna la dificultad por posición. Luna recibe
esas diez combinaciones y devuelve solamente id, pregunta Q y respuesta R.
No genera distractores.

La pantalla jugable conserva temporalmente la generación anterior hasta
conectar Terra (validación/corrección y tres distractores). La prueba
empírica usa el prompt real de Luna y **no envía historial U**.

Desde la raíz del repositorio, con el servicio de IA preparado por el propio lanzador:

```powershell
.\apps\quizai\run.ps1 -ProbarLuna -Muestras 1
.\apps\quizai\run.ps1 -ProbarLuna -Muestras 20
```

Se admite `-LunaSemilla 20260929` para reproducir el sorteo de P–D y
`-CatalogModel` para elegir el modelo. El verificador existente
`tool/verify_generation.dart` guarda las preguntas, respuestas, instrucciones
D y uso de tokens en `.ai-apps/experimentos-luna-pd/` como JSONL y Markdown.
El informe cuenta repeticiones textuales de R por P, distinguiendo
coincidencias con igual D y con distintas D. No identifica sinónimos;
para atribuir causalidad a D se necesitará un control sin D.

### Control sin dimensiones D

Para comparar con las primeras 50 llamadas P+D, se utiliza el mismo modelo,
las mismas semillas, los mismos pivotes P y la misma distribución de dificultad.
Solo se elimina D del prompt enviado a Luna; tampoco se proporciona historial U.

```powershell
.\apps\quizai\run.ps1 -ProbarLuna -SinD -Muestras 50 -LunaSemilla 20260929
```

El control guarda sus resultados separados en
`.ai-apps/experimentos-luna-pd/luna-p-*.jsonl` y `luna-p-*.md`.
La prueba P+D previa se conserva intacta. Las estadísticas del control
cuentan las respuestas R distintas y repetidas dentro de cada P.

### Control sin D y con U en bloques de 10 llamadas

Esta variante mantiene P, dificultad, modelo y semilla del control sin D.
En cada bloque U comienza vacío; recibe las respuestas R de las llamadas
anteriores y vuelve a vaciarse antes de las llamadas 11, 21, ..., 91.
Luna recibe solo la lista U y no recibe dimensiones D ni preguntas anteriores.

```powershell
.\apps\quizai\run.ps1 -ProbarLuna -SinD -ConU -Muestras 100 -LunaSemilla 20260929
```

Las 100 llamadas son diez bloques independientes de diez. El verificador
reutilizado registra U por llamada y las coincidencias textuales de R con U,
sin descartar respuestas infractoras (forman parte del experimento).
Los resultados se guardan como `luna-pu-*.jsonl` y `luna-pu-*.md`
en el directorio habitual. Se guardan por llamada; al interrumpir el lote,
se conservan las llamadas terminadas.

La opción `-VerifyOnly` de la partida anterior se mantiene sin cambios.
