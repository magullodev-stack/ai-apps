# IA compartida

El módulo JVM `ai` recupera el cliente de Responses, el transporte HTTP, la configuración y el registro de consumo del historial anterior a la limpieza. Las dependencias originales `core/config`, `core/contracts` y `core/network` se ubican ahora dentro de `ai/core/`; la herramienta MONIT-AI y las funciones antiguas de Quiz10 siguen archivadas.

Cada tarea puede elegir un modelo mediante `StructuredGenerationRequest(model = "...")`. Los perfiles LUNA, MINI y TERRA se conservan solo como compatibilidad con las pruebas antiguas; no limitan los modelos que puede usar un juego. El cliente implementa por ahora salidas JSON estructuradas. Los prompts, los esquemas y las reglas pertenecen a cada juego.

## Puente local para juegos Flutter

`AiHttpServer` expone `POST /v1/generate` en `127.0.0.1:8787`. Recibe `application`, `model`, `input`, `schemaName` y `schema` (objeto JSON). Devuelve `text` y, cuando está disponible, `usage`. El servidor utiliza la clave OpenAI y registra los metadatos técnicos de las llamadas sin registrar prompts ni respuestas. Los errores del proveedor se reducen a `upstream_failure`; no se devuelve la clave ni el cuerpo de error de OpenAI.

En PowerShell, desde la raíz del repositorio:

1. Define `AI_APPS_AI_API_KEY` en el entorno del proceso, sin escribirla en el repositorio.
2. Define `AI_APPS_GAME_TOKEN` como secreto local distinto de la clave OpenAI.
3. Ejecuta `.\gradlew.bat :ai:run` con JDK 21 disponible.
4. En un juego Flutter, añade una dependencia local a `../../ai/flutter_client` (ajusta la ruta según el juego) y utiliza `AiAppsClient` con la URL del servidor.

El servidor escucha solo en loopback. Para un emulador Android de desarrollo se puede usar `adb reverse tcp:8787 tcp:8787` y `http://127.0.0.1:8787`; la aplicación necesita permiso de red y permitir HTTP local en su configuración de desarrollo. No incluyas `AI_APPS_GAME_TOKEN` en una versión distribuida: para producción, el juego necesita un backend con autenticación de usuarios que invoque el cliente de OpenAI. Este puente no sustituye esa capa de seguridad.

La URL de OpenAI se puede cambiar mediante `AI_APPS_AI_BASE_URL` (HTTPS o HTTP local). `AI_APPS_AI_MODEL` sirve de modelo de reserva para el uso directo del cliente JVM con perfiles antiguos. `AI_APPS_GAME_PORT` permite cambiar el puerto. `AI_APPS_USAGE_FILE` determina el archivo JSONL de consumo; el valor por defecto es `.ai-apps/usage/ai-usage.jsonl`.

## Comprobaciones

`.\gradlew.bat :ai:test :ai:core:config:test :ai:core:network:test :ai:core:contracts:test` ejecuta pruebas sin llamar a OpenAI. La prueba real antigua `OpenAiResponsesSmokeTest` requiere `AI_APPS_AI_SMOKE=1` y las variables de entorno documentadas en `EnvironmentConfig`; ejecútala solo tras coordinar una llamada real.
