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
