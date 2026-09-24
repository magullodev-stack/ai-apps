# QuizAI

Aplicación con la modalidad estándar 🎲 Quiz10: diez preguntas de cultura general generadas mediante IA.

En la modalidad 🎲 se eligen diez áreas distintas y las preguntas siguen esta progresión: cuatro fáciles, tres moderadas, dos difíciles y una muy difícil. Cada pregunta tiene cuatro opciones; cada acierto suma un punto. Al finalizar se muestra el resultado sobre diez.

## Identidad visual de QuizAI

La pantalla principal utiliza una identidad propia de videojuego móvil:
fondo morado degradado, cabecera destacada, tarjetas de colores, bordes
redondeados, sombras y navegación inferior integrada.

Quiz10 es la modalidad protagonista y conserva su acceso directo a la
partida existente. Sala, 1vs1 y Estudio mantienen su estado no disponible.

Los indicadores de puntos, racha y ranking muestran un guion hasta que
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
Los estilos particulares existentes siguen utilizando sus tamaños
y pesos hasta que se complete el rediseño de cada pantalla.

La interfaz está preparada para incorporar ilustraciones propias de QuizAI.
Su ausencia no impide utilizar la navegación ni iniciar Quiz10.

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