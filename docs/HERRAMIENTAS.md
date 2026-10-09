# HERRAMIENTAS.md — AI-APPS

## Catálogo activo

| Herramienta | Finalidad | Ubicación | Instrucciones |
| --- | --- | --- | --- |
| QuizAI con IA | Iniciar o reutilizar el servicio Dart, ejecutar QuizAI en el dispositivo Android seleccionado y mantener Hot Reload automático durante el desarrollo; auditar Luna con `-ProbarLuna -Muestras N`, auditar el pipeline Luna→revisor→Dart con `-ProbarQuiz10 -Muestras N` y detener el servicio con `-StopService`. | [`apps/quizai/run.ps1`](../apps/quizai/run.ps1) | [`apps/quizai/README.md`](../apps/quizai/README.md) y [`ai/README.md`](../ai/README.md). |
| Sincronización continua de `dev` | Mantener `dev` local y `origin/dev` sincronizados en segundo plano mientras QuizAI está en desarrollo. Aplica cambios remotos automáticamente y, tras unos segundos sin cambios locales, crea un commit de sincronización y lo publica. | [`scripts/auto-sync-dev.ps1`](../scripts/auto-sync-dev.ps1) | Se inicia automáticamente desde `apps/quizai/run.ps1`; no se ejecuta manualmente. |
| Sincronizar `dev` manualmente | Herramienta de recuperación/fallback para forzar una sincronización bidireccional cuando la sincronización continua no está activa. | [`scripts/sync-dev.ps1`](../scripts/sync-dev.ps1) | Solo para recuperación o diagnóstico. |
| Flutter Dev Runner | Ejecutar `flutter run --machine`, vigilar código y assets de QuizAI y de sus dependencias locales y solicitar Hot Reload al proceso Flutter después de cambios en disco. | [`scripts/flutter-dev-runner.dart`](../scripts/flutter-dev-runner.dart) | Se inicia desde `apps/quizai/run.ps1`; no se ejecuta manualmente. |

---


## Android físico compartido

`scripts/start-android.ps1` prepara un dispositivo Android físico que ya esté
conectado mediante ADB. Nunca inicia un emulador.

Si ADB publica el mismo móvil mediante IP y mediante mDNS, el procedimiento
prefiere la identidad inalámbrica estable. Si el móvil ya estaba emparejado pero
todavía no aparece en `adb devices`, intenta recuperarlo mediante mDNS. Al
preparar el dispositivo físico cierra los emuladores Android que hayan quedado
conectados de sesiones anteriores, para evitar que VS Code los conserve como
destino de Flutter. Si no puede recuperar ningún dispositivo físico, termina con
un error explícito.

`scripts/vscode-android/` contiene la integración local de VS Code.

Al abrir el repositorio AI-APPS, la integración prepara el dispositivo físico
y ejecuta en él el juego seleccionado en `.ai-apps/active-game.txt`. No abre
EmbeDroid ni inicia un AVD.

La integración local se instala con
`scripts/install-vscode-android.ps1`. Su código fuente permanece en el
repositorio.

Si `.ai-apps/active-game.txt` contiene `none`, no se ejecuta ningún juego.
Si el selector local no existe y QuizAI está disponible, la integración usa
QuizAI como aplicación de desarrollo por defecto. Cada aplicación conserva su
propio lanzador `apps/<juego>/run.ps1`.

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



## Sincronización continua de `dev`

Al iniciar QuizAI mediante `apps/quizai/run.ps1`, se arranca también
`scripts/auto-sync-dev.ps1` en segundo plano. Un bloqueo local evita lanzar
más de una instancia.

Mientras el repositorio está en `dev`, el proceso comprueba periódicamente
`origin/dev`. Si hay cambios remotos y el árbol local está limpio, aplica un
fast-forward automáticamente; los archivos Dart y assets modificados son
recogidos por el Flutter Dev Runner y disparan Hot Reload.

Los cambios locales permanecen unos segundos en espera para evitar sincronizar
un archivo mientras todavía se está editando. Cuando se estabilizan, el proceso
los añade, crea un commit `Auto-sync ai-apps`, integra `origin/dev` y publica
el resultado. Si aparece un conflicto de rebase, aborta ese intento y conserva
el trabajo local; no resuelve conflictos destruyendo cambios.

El registro está en `.ai-apps/auto-sync-dev.log`. `scripts/sync-dev.ps1`
queda como herramienta manual de recuperación, no como parte del flujo normal
de desarrollo.

Los cambios de dependencias, configuración nativa o `pubspec.yaml` siguen
pudiendo requerir un reinicio completo de Flutter; los cambios normales de Dart
y assets no requieren sincronización manual ni reinicio.
