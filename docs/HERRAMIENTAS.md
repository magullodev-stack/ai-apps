# HERRAMIENTAS.md — AI-APPS

## Catálogo activo

| Herramienta | Finalidad | Ubicación | Instrucciones |
| --- | --- | --- | --- |
| QuizAI con IA | Iniciar o reutilizar el servicio Dart, ejecutar QuizAI en el dispositivo Android seleccionado y mantener Hot Reload automático durante el desarrollo; auditar Luna con `-ProbarLuna -Muestras N`, auditar el pipeline Luna→revisor→Dart con `-ProbarQuiz10 -Muestras N` y detener el servicio con `-StopService`. | [`apps/quizai/run.ps1`](../apps/quizai/run.ps1) | [`apps/quizai/README.md`](../apps/quizai/README.md) y [`ai/README.md`](../ai/README.md). |
| Sincronizar `dev` | Sincronizar bidireccionalmente cualquier proyecto de AI-APPS con `origin/dev` desde cualquier subcarpeta del repositorio. Si QuizAI está ejecutándose mediante el lanzador de desarrollo, los cambios Dart y de assets sincronizados disparan Hot Reload automáticamente. | [`scripts/sync-dev.ps1`](../scripts/sync-dev.ps1) | Sección «Sincronización universal de `dev`» de este documento. |
| Flutter Dev Runner | Ejecutar `flutter run --machine`, vigilar código y assets de QuizAI y de sus dependencias locales y solicitar Hot Reload al proceso Flutter después de cambios en disco. | [`scripts/flutter-dev-runner.dart`](../scripts/flutter-dev-runner.dart) | Se inicia desde `apps/quizai/run.ps1`; no se ejecuta manualmente. |

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

`apps/quizai/run.ps1` inicia Flutter mediante
`scripts/flutter-dev-runner.dart`. El runner vigila los archivos Dart,
assets de QuizAI y las dependencias locales compartidas usadas por la app.

Cuando `git pull` o `scripts/sync-dev.ps1` modifica esos archivos, el
runner agrupa los eventos y solicita automáticamente un Hot Reload incremental
a la sesión Flutter activa. No es necesario pulsar `r` después de cada
sincronización.

La terminal conserva los atajos manuales: `r` fuerza Hot Reload, `R` hace
Hot Restart y `q` termina la sesión. Los cambios de dependencias, configuración
nativa o `pubspec.yaml` pueden requerir reiniciar la sesión de desarrollo.

