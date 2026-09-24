# Quiz10 🎲

Juego de diez preguntas de cultura general generadas mediante IA.

En la modalidad 🎲 se eligen diez áreas distintas y las preguntas siguen esta progresión: cuatro fáciles, tres moderadas, dos difíciles y una muy difícil. Cada pregunta tiene cuatro opciones; cada acierto suma un punto. Al finalizar se muestra el resultado sobre diez.

## Ejecutar con IA

Con `emulator-5554` iniciado, desde la raíz del repositorio en PowerShell:

```powershell
.\scripts\run-android.ps1
```

El procedimiento inicia o reutiliza el servicio Dart, conecta el emulador y pasa automáticamente la configuración de desarrollo con `gpt-4.1-mini`. Busca la clave OpenAI en el entorno y, si falta, la solicita con entrada oculta. No es necesario introducir un token; la clave no se incluye en Flutter ni en el APK. La tarea manual de VS Code **AI-APPS: ejecutar Quiz10 con IA** usa este mismo procedimiento.

La generación usa el Dart incluido en Flutter. El proyecto Android conserva su compilación independiente. El prompt y las reglas siguen en Quiz10; el esquema no envía `minItems` ni `maxItems` y el validador sigue exigiendo diez preguntas.

Consulta [`ai/README.md`](../../ai/README.md) para las variables, diagnósticos, seguridad y ciclo de vida del servicio. El registro está en `.ai-apps/dart-service.log`; `scripts/run-android.ps1 -StopService` detiene el servicio local. En Flutter, `r` aplica Hot Reload, `R` reinicia la partida y `q` cierra la sesión.

## Comprobaciones

Desde `apps/quiz10`:

```powershell
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

Las pruebas automatizadas del generador, validador, partida y conexión al servicio utilizan un proveedor simulado. El APK se genera en `build/app/outputs/flutter-apk/app-debug.apk`.

Para una generación real explícita, desde la raíz:

```powershell
.\scripts\run-android.ps1 -VerifyOnly
```

La comprobación usa `gpt-4.1-mini` y solo tiene éxito si el validador de Quiz10 acepta diez preguntas. No modifica la sesión Android. El resultado sin contenido ni credenciales queda en `.ai-apps/quiz10-verification.json`.
