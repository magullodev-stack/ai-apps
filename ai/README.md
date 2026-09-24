# IA compartida

`ai/dart_service` implementa el servicio local de desarrollo de AI-APPS con las bibliotecas estándar de Dart (`dart:io` y `dart:convert`). Utiliza el Dart incluido en Flutter y no necesita dependencias de ejecución adicionales.

`ai/flutter_client` conserva el cliente móvil `AiAppsClient`. Las aplicaciones son responsables de sus prompts, esquemas, modelos y validación; el servicio no conoce las reglas de Quiz10.

## Ejecución

Desde PowerShell, en la raíz del repositorio:

```powershell
.\scripts\run-android.ps1
```

Este único procedimiento inicia o reutiliza el servicio Dart, configura `adb reverse` y ejecuta Quiz10 en `emulator-5554` con `gpt-4.1-mini`. El emulador debe estar iniciado. Consulta [`apps/quizai/README.md`](../apps/quizai/README.md) para las instrucciones completas.

El script busca `AI_APPS_AI_API_KEY` y `OPENAI_API_KEY` en el entorno del proceso, usuario y máquina, en ese orden. Si faltan, solicita la clave mediante `Read-Host -AsSecureString`. No la muestra ni la guarda en archivos; solo el proceso Dart la recibe. El script elimina esas variables del entorno heredado por Flutter y nunca las incluye en los parámetros del APK.

El token de comunicación local se genera con un generador criptográfico y se gestiona automáticamente. El servicio escucha exclusivamente en `127.0.0.1`, en un puerto libre elegido por el sistema. La sesión y los parámetros móviles se guardan bajo `.ai-apps/`, excluido de Git; contienen el token local, no la clave de OpenAI. El servicio se mantiene disponible tras cerrar Flutter para permitir revisar la aplicación y reutilizar la sesión. Para detenerlo:

```powershell
.\scripts\run-android.ps1 -StopService
```

El APK de desarrollo incluye el token local y no debe distribuirse. La producción requiere un backend con autenticación de usuarios.

## Contrato HTTP

Todas las rutas requieren `Authorization: Bearer <token local>`.

- `GET /health`: identifica el servicio, la versión del protocolo y su proceso.
- `POST /v1/generate`: recibe `application`, `model`, `input`, `schemaName` y `schema` (objeto JSON). Devuelve `text` y, si está disponible, `usage` con `inputTokens`, `outputTokens` y `totalTokens`.

El servicio envía el prompt y el esquema a `https://api.openai.com/v1/responses` usando `text.format` de tipo `json_schema`, `strict: true` y `store: false`. El contrato sigue la [documentación oficial de salidas estructuradas](https://developers.openai.com/api/docs/guides/structured-outputs); [gpt-4.1-mini](https://developers.openai.com/api/docs/models/gpt-4.1-mini) admite este mecanismo. La selección del modelo corresponde al consumidor.

Los rechazos del proveedor devuelven HTTP 502, `error: provider_rejected` y `diagnostic` con el estado HTTP original, código, tipo, parámetro, mensaje e identificador de solicitud disponibles. `AiAppsException` conserva este diagnóstico. Se ocultan las claves, el token local y los patrones de credenciales en los mensajes; no se vuelcan cabeceras, prompts ni respuestas completas. Los errores no JSON, respuestas incompletas, rechazos de contenido, fallos de conexión y tiempos de espera también se distinguen. No hay reintentos automáticos.

El registro `.ai-apps/dart-service.log` contiene duración, estado, modelo, aplicación, uso de tokens y diagnósticos saneados. No calcula costes ni conserva contenido generado. El plazo máximo del proveedor es 75 segundos; el juego espera hasta 90 segundos.

## Verificación

```powershell
$flutter = Join-Path $env:USERPROFILE 'development\flutter\bin\flutter.bat'
Set-Location 'C:\Users\Miquelet\repos\ai-apps\ai\dart_service'
& $flutter pub get
& $flutter analyze
& $flutter test
```

Las pruebas del servicio utilizan un proveedor HTTP simulado: comprueban el contrato Responses, autenticación, límites, respuestas incompletas, errores del proveedor, timeout y ausencia de credenciales en diagnósticos. Las pruebas de Quiz10 comprueban además el recorrido completo cliente → servicio Dart → proveedor simulado → validador y partida.

La prueba real es explícita y no forma parte de `flutter test`:

```powershell
Set-Location 'C:\Users\Miquelet\repos\ai-apps'
.\scripts\run-android.ps1 -VerifyOnly
```

Genera preguntas con `gpt-4.1-mini` mediante el servicio activo y utiliza el generador, validador y constructor de partida reales de Quiz10. Solo devuelve éxito si acepta diez preguntas. Guarda un comprobante sin contenido ni credenciales en `.ai-apps/quizai-verification.json`. Si falla, consulta el diagnóstico del proveedor en el registro. Esta comprobación no inicia ni modifica una sesión Android.
