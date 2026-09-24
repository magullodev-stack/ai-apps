# Quiz10 · modalidad 🎲

Aplicación Flutter independiente de desarrollo. El contador de ejemplo se ha sustituido por una partida de diez preguntas generadas mediante IA.

## Funcionamiento

Pulsa **🎲 Jugar** para seleccionar diez áreas distintas entre Matemáticas, Física, Química, Tierra y espacio, Biología, Salud, Informática, Ingeniería, Arquitectura, Historia, Lingüística, Literatura, Filosofía, Derecho, Economía, Psicología, Sociología y Ciencia política.

Las preguntas siguen siempre esta progresión: cuatro **Fácil**, tres **Moderado**, dos **Difícil** y una **Muy difícil**. Quiz10 completa la columna Área del prompt antes de solicitar la generación. El prompt y el esquema JSON están en `lib/quiz_generation.dart`.

La salida es un objeto `preguntas` con diez filas y los campos `Dificultad`, `Área`, `Pregunta`, `Correcta`, `Distractor 1`, `Distractor 2` y `Distractor 3`. Antes de iniciar la partida se comprueba que hay exactamente diez filas, que su área y dificultad coinciden con las solicitadas en ese orden, que todos los campos son textos completos y que las cuatro respuestas son distintas, ignorando mayúsculas y espacios repetidos. Una respuesta inválida impide iniciar la partida y permite volver a generar pulsando 🎲. La validación estructural no verifica la exactitud factual ni la dificultad real del contenido generado.

Cada pregunta muestra sus cuatro opciones barajadas. Solo se admite una respuesta: cada acierto suma un punto y cada fallo suma cero, sin penalización. Tras responder se muestra si has acertado y, si fallas, la respuesta correcta. **Siguiente** avanza; **Ver resultado** termina la décima pregunta. El progreso cuenta las preguntas respondidas y el resultado muestra los aciertos sobre diez. **🎲 Otra partida** reinicia la puntuación y solicita una nueva selección y generación.

Durante la generación se muestra un indicador de carga y se impiden solicitudes duplicadas. Los fallos de conexión y el tiempo de espera de 90 segundos permiten reintentar manualmente; no hay reintentos automáticos. El estado se mantiene en memoria y se pierde al reiniciar la aplicación.

## Integración

- `lib/quiz.dart`: selección, validación y reglas de partida.
- `lib/quiz_generation.dart`: prompt, esquema y adaptación de `AiAppsClient`.
- `lib/main.dart`: conexión de desarrollo e interfaz de juego.
- `../../ai/flutter_client`: cliente HTTP compartido, sin duplicar transporte ni incorporar reglas de Quiz10 a `ai/` o `shared/`.

El puente y las credenciales del servidor se describen en [`ai/README.md`](../../ai/README.md). Quiz10 utiliza `POST /v1/generate` con `application: quiz10` y el mecanismo existente de JSON estructurado.

## Entorno local

Utiliza PowerShell de Windows y las instalaciones nativas existentes:

- Flutter: `%USERPROFILE%\development\flutter`; incluye Dart.
- Android SDK: `%LOCALAPPDATA%\Android\Sdk`.
- Compilación Android: JBR incluido en Android Studio en `C:\Program Files\Android\Android Studio\jbr`. Utiliza Flutter para compilar.
- Puente JVM de IA: JDK 21, según `ai/README.md`.
- VS Code: extensiones Dart y Flutter.

```powershell
$flutter = Join-Path $env:USERPROFILE 'development\flutter\bin\flutter.bat'
$androidSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb = Join-Path $androidSdk 'platform-tools\adb.exe'

& $flutter --version
& $flutter doctor -v
```

## Verificación y compilación

```powershell
Set-Location 'C:\Users\Miquelet\repos\ai-apps\apps\quiz10'
& $flutter pub get
& $flutter analyze
& $flutter test
& $flutter build apk --debug

git diff --check
```

Comprueba el resultado de cada comando antes de continuar. Las pruebas cubren selección sin repetición, progresión, campos y opciones inválidos, barajado, respuestas, puntuación, progreso, errores, reintentos y nueva partida. La prueba de integración usa el cliente compartido contra un servidor HTTP simulado en loopback; ninguna prueba llama a un modelo real.

El APK se genera en `build\app\outputs\flutter-apk\app-debug.apk`. Una compilación sin parámetros permite comprobar la interfaz, pero necesita la configuración siguiente para generar preguntas.

## Ejecución manual con IA

Coordina las llamadas reales a modelos y cualquier ejecución que pueda afectar a una sesión Android activa. No se inicia Android como parte de las pruebas ni de la compilación.

1. En una terminal del servidor, configura `AI_APPS_AI_API_KEY` y `AI_APPS_GAME_TOKEN` en el entorno del proceso, sin guardarlos en el repositorio. El token local debe ser distinto de la clave OpenAI. Con JDK 21 disponible:

   ```powershell
   Set-Location 'C:\Users\Miquelet\repos\ai-apps'
   .\gradlew.bat :ai:run
   ```

2. En la terminal de Flutter, configura `AI_APPS_GAME_TOKEN` con el mismo token local y `AI_APPS_AI_MODEL` con el identificador del modelo que quieras utilizar. No hay un modelo predeterminado en Quiz10: el puente requiere que cada solicitud lo indique. No pases la clave OpenAI a Flutter.

3. Con el dispositivo o emulador ya iniciado manualmente, consulta su identificador y establece la conexión al puente:

   ```powershell
   & $flutter devices
   $device = '<identificador-del-dispositivo>'
   & $adb -s $device reverse tcp:8787 tcp:8787
   ```

4. Ejecuta la aplicación pasando explícitamente los parámetros de desarrollo (Flutter no lee automáticamente estas variables del entorno):

   ```powershell
   if ([string]::IsNullOrWhiteSpace($env:AI_APPS_GAME_TOKEN) -or
       [string]::IsNullOrWhiteSpace($env:AI_APPS_AI_MODEL)) {
       throw 'Configura AI_APPS_GAME_TOKEN y AI_APPS_AI_MODEL en esta terminal.'
   }
   Set-Location 'C:\Users\Miquelet\repos\ai-apps\apps\quiz10'
   & $flutter run -d $device `
       '--dart-define=AI_APPS_AI_URL=http://127.0.0.1:8787' `
       "--dart-define=AI_APPS_GAME_TOKEN=$env:AI_APPS_GAME_TOKEN" `
       "--dart-define=AI_APPS_AI_MODEL=$env:AI_APPS_AI_MODEL"
   ```

La URL predeterminada es `http://127.0.0.1:8787`. Si cambias `AI_APPS_GAME_PORT` en el servidor, adapta el puerto en `adb reverse` y `AI_APPS_AI_URL`. Android permite HTTP local solo para `127.0.0.1` y `localhost` en la configuración **debug**. Los parámetros también pueden pasarse a `flutter build apk --debug` si vas a instalar el APK manualmente. El token se incorpora al artefacto de desarrollo: no distribuyas ese APK. La producción requiere el backend con autenticación descrito en `ai/README.md`.

El script existente `scripts/run-android.ps1` y la tarea de VS Code sirven para la ejecución Android general, pero no pasan estos parámetros de IA. Para jugar con generación utiliza el comando anterior; no inicies ambas sesiones a la vez.

## Hot Reload

En la sesión de `flutter run`, cambia un texto visible de `lib/main.dart`, guarda y pulsa `r`: la partida y su puntuación se conservan. Restaura el texto de prueba. `R` reinicia la aplicación y `q` cierra la sesión. Los cambios de parámetros `--dart-define` requieren volver a ejecutar Flutter.
