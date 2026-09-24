# HERRAMIENTAS.md — AI-APPS

## Catálogo activo

| Herramienta | Finalidad | Ubicación | Instrucciones |
| --- | --- | --- | --- |
| QuizAI con IA | Iniciar o reutilizar el servicio Dart, conectar el emulador y ejecutar QuizAI; verificar una generación real de la modalidad Quiz10 con `-VerifyOnly`; detener el servicio con `-StopService`. | [`scripts/run-android.ps1`](../scripts/run-android.ps1) | [`apps/quiz10/README.md`](../apps/quiz10/README.md) y [`ai/README.md`](../ai/README.md). |

La tarea manual de VS Code **AI-APPS: ejecutar QuizAI con IA** utiliza este mismo script. Por defecto trabaja con `emulator-5554` y `gpt-4.1-mini`.

---

## COMMIT

$ErrorActionPreference = 'Stop'
if ((git branch --show-current) -ne 'dev') { throw 'La rama activa no es dev' }
git add -A
if ($LASTEXITCODE -ne 0) { throw 'Falló git add' }
git diff --cached --check
if ($LASTEXITCODE -ne 0) { throw 'Hay errores en los cambios' }
git commit -m 'Descripción del cambio'
if ($LASTEXITCODE -ne 0) { throw 'Falló el commit' }
git pull --rebase origin dev
if ($LASTEXITCODE -ne 0) { throw 'Falló el pull; no se hizo push' }
git push origin dev
if ($LASTEXITCODE -ne 0) { throw 'Falló el push' }
git rev-parse HEAD
git status --short --branch
