# HERRAMIENTAS.md — AI-APPS

## Catálogo activo

| Herramienta | Finalidad | Ubicación | Instrucciones |
| --- | --- | --- | --- |
| QuizAI con IA | Iniciar o reutilizar el servicio Dart, conectar el emulador y ejecutar QuizAI; auditar Luna con `-ProbarLuna -Muestras N`, auditar el pipeline Luna→revisor→Dart con `-ProbarQuiz10 -Muestras N` y detener el servicio con `-StopService`. | [`apps/quizai/run.ps1`](../apps/quizai/run.ps1) | [`apps/quizai/README.md`](../apps/quizai/README.md) y [`ai/README.md`](../ai/README.md). |
| Sincronizar `dev` | Sincronizar bidireccionalmente cualquier proyecto de AI-APPS con `origin/dev` desde cualquier subcarpeta del repositorio. | [`scripts/sync-dev.ps1`](../scripts/sync-dev.ps1) | Sección «Sincronización universal de `dev`» de este documento. |

---


## Android físico compartido

`scripts/start-android.ps1` prepara un dispositivo Android físico que ya esté
conectado mediante ADB. Nunca inicia un emulador.

Si ADB publica el mismo móvil mediante IP y mediante mDNS, el procedimiento
prefiere la identidad inalámbrica estable. Si no hay ningún dispositivo físico
conectado, termina con un error explícito.

`scripts/vscode-android/` contiene la integración local de VS Code.

Al abrir el repositorio AI-APPS, la integración prepara el dispositivo físico
y ejecuta en él el juego seleccionado en `.ai-apps/active-game.txt`. No abre
EmbeDroid ni inicia un AVD.

La integración local se instala con
`scripts/install-vscode-android.ps1`. Su código fuente permanece en el
repositorio.

Si `.ai-apps/active-game.txt` contiene `none`, no se ejecuta ningún juego.
Cada aplicación conserva su propio lanzador `apps/<juego>/run.ps1`.

El selector es local y no se publica en Git. Para consultar los diagnósticos
del arranque, abre el panel Output de VS Code y selecciona
`AI-APPS Android`.


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