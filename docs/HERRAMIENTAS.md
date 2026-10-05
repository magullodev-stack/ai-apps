# HERRAMIENTAS.md — AI-APPS

## Catálogo activo

| Herramienta | Finalidad | Ubicación | Instrucciones |
| --- | --- | --- | --- |
| QuizAI con IA | Iniciar o reutilizar el servicio Dart, conectar el emulador y ejecutar QuizAI; auditar Luna con `-ProbarLuna -Muestras N`, auditar el pipeline Luna→revisor→Dart con `-ProbarQuiz10 -Muestras N` y detener el servicio con `-StopService`. | [`apps/quizai/run.ps1`](../apps/quizai/run.ps1) | [`apps/quizai/README.md`](../apps/quizai/README.md) y [`ai/README.md`](../ai/README.md). |
| Sincronizar `dev` | Sincronizar bidireccionalmente cualquier proyecto de AI-APPS con `origin/dev` desde cualquier subcarpeta del repositorio. | [`scripts/sync-dev.ps1`](../scripts/sync-dev.ps1) | Sección «Sincronización universal de `dev`» de este documento. |

---


## Emulador Android compartido

`scripts/start-android.ps1` prepara el dispositivo Android de AI-APPS.

El procedimiento reutiliza un emulador conectado o inicia el AVD
Medium_Phone sin ventana externa. Durante el arranque distingue los estados
`offline` y `device`: solo consulta `sys.boot_completed` cuando ADB indica
`device`, y tolera una desconexión transitoria entre consultas. Mantiene
el límite de espera de 240 segundos y devuelve el identificador del
dispositivo preparado.

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

.\scripts\sync-dev.ps1

---

## USUARIO H
.\scripts\sync-dev.ps1
.\apps\quizai\run.ps1 -ProbarQuiz10 -Muestras 20

---

## COLA USUARIOS
.\scripts\sync-dev.ps1
.\apps\quizai\run.ps1 -ProbarQuiz10 -Usuarios 20

---

## HOT RELOAD FLUTTER

en la terminal donde está vivo flutter run, usa:
r

Eso reconstruye la aplicación desde cero y ejecutará el nuevo initState