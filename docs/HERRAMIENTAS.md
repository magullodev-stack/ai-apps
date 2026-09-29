# HERRAMIENTAS.md — AI-APPS

## Catálogo activo

| Herramienta | Finalidad | Ubicación | Instrucciones |
| --- | --- | --- | --- |
| QuizAI con IA | Iniciar o reutilizar el servicio Dart, conectar el emulador y ejecutar QuizAI; verificar una generación real de la modalidad Quiz10 con `-VerifyOnly`; detener el servicio con `-StopService`. | [`apps/quizai/run.ps1`](../apps/quizai/run.ps1) | [`apps/quizai/README.md`](../apps/quizai/README.md) y [`ai/README.md`](../ai/README.md). |

La tarea manual de VS Code **AI-APPS: ejecutar QuizAI con IA** utiliza este mismo script. Por defecto trabaja con `emulator-5554` y `gpt-4.1-mini`.

---


## Emulador Android compartido

`scripts/start-android.ps1` prepara el dispositivo Android de AI-APPS.

El procedimiento reutiliza un emulador conectado o inicia el AVD
Medium_Phone sin ventana externa. Espera a que Android termine de
arrancar y devuelve el identificador del dispositivo preparado.

No ejecuta ninguna aplicación ni inicia servicios de inteligencia
artificial.

`scripts/vscode-android/` contiene la integración local de VS Code.

Al abrir el repositorio AI-APPS, esta integración ejecuta el procedimiento
compartido y utiliza el comando público `embedroid.openEmbedded` para
mostrar Android dentro de una pestaña del editor.

La extensión EmbeDroid debe estar instalada.

La integración local se instala en el directorio de extensiones de VS Code.
Su código fuente permanece en el repositorio.

El visor utiliza el grupo de editores activo, permitiendo alternar entre
los documentos y el teléfono mediante sus pestañas.

Para consultar los diagnósticos del arranque, abrir el panel Output de
VS Code y seleccionar `AI-APPS Android`.

El emulador es una herramienta compartida. Después de prepararlo, la
integración ejecuta el juego seleccionado en `.ai-apps/active-game.txt`.
Si el archivo contiene `none`, no ejecuta ningún juego. Cada aplicación
conserva su propio lanzador `apps/<juego>/run.ps1`.

El selector es local y no se publica en Git. Cambiarlo permite elegir
qué aplicación se ejecutará la próxima vez que se abra AI-APPS.

La tarea existente `AI-APPS: ejecutar QuizAI con IA` sigue siendo manual
y reutiliza Android cuando ya está conectado.

---

## COMMIT

$ErrorActionPreference = 'Stop'
cd C:\Users\Miquelet\repos\ai-apps

if ((git branch --show-current) -ne 'dev') {
    throw 'La rama activa no es dev.'
}

git add -A
if ($LASTEXITCODE -ne 0) { throw 'Falló git add.' }

git diff --cached --check
if ($LASTEXITCODE -ne 0) { throw 'Hay errores en los cambios.' }

git diff --cached --quiet
if ($LASTEXITCODE -eq 1) {
    git commit -m "Actualizar AI-APPS"
    if ($LASTEXITCODE -ne 0) { throw 'Falló el commit.' }
}

git pull --rebase origin dev
if ($LASTEXITCODE -ne 0) { throw 'Falló el pull; no se hizo push.' }

git push origin dev
if ($LASTEXITCODE -ne 0) { throw 'Falló el push.' }

git rev-parse HEAD
git status --short --branch

---

# COMMIT DESDE GIT A VS-CODE (GPT)

git pull --ff-only origin dev
git log -1 --oneline

---

# GENERAR PIVOTES

git pull --ff-only origin dev
.\generar-pivotes.ps1 -Ruta