# HERRAMIENTAS.md — AI-APPS

## Catálogo activo

| Herramienta | Finalidad | Ubicación | Instrucciones |
| --- | --- | --- | --- |
| Desarrollo persistente | Preparar Android, Dart y QuizAI al iniciar sesión, con una única sesión Flutter y Hot Reload automático fuera de VS Code. | [`scripts/start-dev-session.ps1`](../scripts/start-dev-session.ps1) y [`scripts/install-dev-session.ps1`](../scripts/install-dev-session.ps1) | Apartado de arranque persistente de este documento. |
| QuizAI con IA | Iniciar o reutilizar el servicio Dart, ejecutar QuizAI en el dispositivo Android seleccionado y mantener Hot Reload automático durante el desarrollo; auditar Luna con `-ProbarLuna -Muestras N`, auditar el pipeline Luna→revisor→Dart con `-ProbarQuiz10 -Muestras N` y detener el servicio con `-StopService`. | [`apps/quizai/run.ps1`](../apps/quizai/run.ps1) | [`apps/quizai/README.md`](../apps/quizai/README.md) y [`ai/README.md`](../ai/README.md). |
| Sincronización continua de `dev` | Mantener `dev` local y `origin/dev` sincronizados en segundo plano mientras QuizAI está en desarrollo. Aplica cambios remotos automáticamente y, tras unos segundos sin cambios locales, crea un commit de sincronización y lo publica. | [`scripts/auto-sync-dev.ps1`](../scripts/auto-sync-dev.ps1) | Se inicia automáticamente desde `apps/quizai/run.ps1`; no se ejecuta manualmente. |
| Sincronizar `dev` manualmente | Herramienta de recuperación/fallback para forzar una sincronización bidireccional cuando la sincronización continua no está activa. | [`scripts/sync-dev.ps1`](../scripts/sync-dev.ps1) | Solo para recuperación o diagnóstico. |
| Flutter Dev Runner | Ejecutar `flutter run --machine`, vigilar código y assets de QuizAI y de sus dependencias locales y solicitar Hot Reload al proceso Flutter después de cambios en disco. | [`scripts/flutter-dev-runner.dart`](../scripts/flutter-dev-runner.dart) | Se inicia desde `apps/quizai/run.ps1`; no se ejecuta manualmente. |
| EmbeDroid en VS Code | Mostrar y controlar el AVD local de desarrollo dentro de una pestaña de VS Code para interacción y capturas rápidas. | Extensión `utpalbarman.embedroid` + [`scripts/vscode-android/`](../scripts/vscode-android/) | Apertura automática solicitada al iniciar AI-APPS; restauración fiable no validada en 1.0.2. [Diagnóstico y alternativa](../scripts/vscode-android/README.md). |

---


## Arranque persistente y Android de desarrollo

Instala una vez la tarea **AI-APPS Development** desde PowerShell, sin administrador:

```powershell
.\scripts\install-dev-session.ps1
Start-ScheduledTask -TaskName 'AI-APPS Development'
```

La tarea usa la sesión interactiva del usuario actual, sin contraseña guardada,
con privilegios limitados y PowerShell oculto/no interactivo. Arranca al iniciar
sesión, ignora nuevas ejecuciones mientras está activa (`IgnoreNew`), no tiene
límite temporal y no se detiene por inactividad ni al pasar a batería.
La configuración corresponde a las opciones del
[Programador de tareas de Windows](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasksettingsset).
Su entrada mínima, `scripts/start-dev-session.ps1`, ejecuta en orden
`scripts/start-ai-apps-android.ps1` y `apps/quizai/run.ps1 -Device emulator-5554`.
El primero reutiliza el emulador o prepara el AVD `AI_APPS_Dev` sin ventana;
el segundo prepara/reutiliza Dart y mantiene el Flutter Dev Runner existente.

El registro `.ai-apps/dev-session.log` contiene estados, errores por etapa y
confirmaciones de Hot Reload. Solo conserva mensajes conocidos: no vuelca logs
de la app, excepciones completas, claves, tokens ni defines. Para diagnosticar
un fallo detallado, detén la tarea y ejecuta el lanzador en PowerShell.
El lanzador necesita la clave previamente guardada con DPAPI para este usuario
o una variable de entorno válida; el arranque oculto no solicita credenciales.

VS Code únicamente abre el Android existente con `embedroid.openEmbedded`.
Cerrar o reabrir el editor no inicia Flutter, Dart ni Gradle. Un fallo del visor
no afecta a la sesión persistente. Los errores de solicitud se registran en
Output → `AI-APPS Android`; los errores de transmisión, en `Android Emulator`
y en la propia pestaña. EmbeDroid 1.0.2 puede cerrar una transmisión nueva
después de reabrir VS Code y no ofrece una reconexión pública automatizable.
Consulta la [limitación técnica y la recuperación manual](../scripts/vscode-android/README.md).
El antiguo selector `.ai-apps/active-game.txt` ya no controla este arranque.
La integración se enlaza al repositorio con `scripts/install-vscode-android.ps1`;
recarga o reabre VS Code después de modificar su JavaScript.

Para consultar o detener la sesión:

```powershell
Get-ScheduledTask -TaskName 'AI-APPS Development'
Get-ScheduledTaskInfo -TaskName 'AI-APPS Development'
Stop-ScheduledTask -TaskName 'AI-APPS Development'
```

No ejecutes `start-dev-session.ps1` directamente ni otro `flutter run` mientras
la tarea esté activa: la exclusión la proporciona el Programador de tareas.
Antes de una prueba manual, detén la tarea y confirma que han terminado el
runner y su Flutter; después restaura con `Start-ScheduledTask`.
Windows puede dejar hijos nativos vivos después de `Stop-ScheduledTask`:
comprueba sus PID con `Get-CimInstance Win32_Process` y detén con `Stop-Process`
solo el runner y los procesos Flutter de esta sesión antes de iniciar otra.
No detengas el emulador ni un Dart que pertenezca al servicio o al editor.
El servicio Dart puede reutilizarse. Su parada explícita sigue siendo
`run.ps1 -StopService`.
La sesión dura hasta detenerla, cerrar la sesión de Windows o apagar el equipo;
al siguiente inicio de sesión vuelve a prepararse.

`scripts/start-android.ps1` conserva la preparación del dispositivo físico para
las comprobaciones que lo requieran.

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
sincronización. La vigilancia funciona también en la tarea oculta, sin terminal ni VS Code.

En una ejecución manual en PowerShell, la terminal conserva los atajos: `r` fuerza Hot Reload, `R` hace
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


## Flujo visual con EmbeDroid

Para el desarrollo cotidiano, QuizAI se ejecuta en el AVD local preparado por
AI-APPS. EmbeDroid abre ese emulador dentro del editor mediante
`embedroid.openEmbedded`, el mismo flujo que ya utilizaba el repositorio antes
de pasar temporalmente al Pixel físico.

La versión 1.0.2 instalada no garantiza restauración automática tras un
cierre completo del editor. Una pestaña abierta no acredita una transmisión
activa. El [diagnóstico de la integración](../scripts/vscode-android/README.md)
recoge el fallo del transporte, las comprobaciones ADB y la alternativa de
visualización con scrcpy sobre el mismo emulador, sin recompilar QuizAI.

El objetivo del flujo es: cambios de código → autosync/local → Hot Reload →
visualización inmediata en EmbeDroid → captura desde el PC. El Pixel físico
queda para comprobaciones finales.
