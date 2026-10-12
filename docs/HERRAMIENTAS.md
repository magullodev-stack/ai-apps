# HERRAMIENTAS.md — AI-APPS

## Catálogo activo

| Herramienta | Finalidad | Ubicación | Instrucciones |
| --- | --- | --- | --- |
| agent-lab: ChatDev → Codex | Un agente de ChatDev decide qué construir, delega en Codex, evalúa resultados y formula nuevas instrucciones autónomas sobre el mismo repositorio aislado. Conserva decisiones, intercambios y cambios por ciclo; conecta apps Flutter experimentales al gestor Android con Hot Reload, captura real del emulador, deliberación multimodal y parada propia. Incluye pruebas offline e instalación y eliminación independientes. | [`agent-lab/`](../agent-lab/) | [`agent-lab/README.md`](../agent-lab/README.md). |
| Desarrollo persistente | Preparar Android, Dart y Muondia al iniciar sesión, con una única sesión Flutter y Hot Reload automático fuera de VS Code. | [`scripts/start-dev-session.ps1`](../scripts/start-dev-session.ps1) y [`scripts/install-dev-session.ps1`](../scripts/install-dev-session.ps1) | Apartado de arranque persistente de este documento. |
| Muondia con IA | Iniciar o reutilizar el servicio Dart, ejecutar Muondia en el dispositivo Android seleccionado y mantener Hot Reload automático durante el desarrollo; auditar Luna con `-ProbarLuna -Muestras N`, auditar el pipeline Luna→revisor→Dart con `-ProbarOnboardingQuiz -Muestras N` y detener el servicio con `-StopService`. | [`apps/muondia/run.ps1`](../apps/muondia/run.ps1) | [`apps/muondia/README.md`](../apps/muondia/README.md) y [`ai/README.md`](../ai/README.md). |
| Sincronización continua de `dev` | Mantener `dev` local y `origin/dev` sincronizados en segundo plano durante la sesión general de desarrollo de AI-APPS. Aplica cambios remotos automáticamente y, tras unos segundos sin cambios locales, crea un commit de sincronización y lo publica. | [`scripts/auto-sync-dev.ps1`](../scripts/auto-sync-dev.ps1) | Se inicia automáticamente desde `scripts/start-dev-session.ps1`; no depende del lanzador de Muondia. |
| Sincronizar `dev` manualmente | Herramienta de recuperación/fallback para forzar una sincronización bidireccional cuando la sincronización continua no está activa. | [`scripts/sync-dev.ps1`](../scripts/sync-dev.ps1) | Solo para recuperación o diagnóstico. |
| Flutter Dev Runner | Ejecutar `flutter run --machine` por aplicación, vigilar sus raíces de código y assets y solicitar Hot Reload a su propio proceso. Muondia conserva su invocación; las sesiones nuevas usan `--no-dds`. Ignora archivos Android generados y recupera su vigilancia tras reinicios nativos. | [`scripts/flutter-dev-runner.dart`](../scripts/flutter-dev-runner.dart) | Se inicia desde Muondia o los workers de [`Android independiente`](../scripts/android/README.md); no se ejecuta manualmente. |
| AI-APPS Android multiemulador | Seleccionar y recuperar visores por aplicación/dispositivo, sin duplicados; registrar, iniciar, detener, capturar la app enfocada y retirar cada sesión independientemente. Conserva Muondia en emulator-5554. | EmbeDroid mantenido + [`scripts/vscode-android/`](../scripts/vscode-android/) y [`scripts/android-session.ps1`](../scripts/android-session.ps1) | [Registro, selector, ciclo de vida y pruebas](../scripts/android/README.md). |
| Construir y validar EmbeDroid | Mantener y reinstalar la distribución corregida sin parches locales en la extensión instalada. | [`scripts/embedroid/`](../scripts/embedroid/) y [`scripts/install-embedroid.ps1`](../scripts/install-embedroid.ps1) | [Procedencia, pruebas y actualizaciones](../scripts/embedroid/README.md). |

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
Su entrada mínima, `scripts/start-dev-session.ps1`, inicia en segundo plano
`scripts/auto-sync-dev.ps1` y después ejecuta en orden
`scripts/start-ai-apps-android.ps1` y `apps/muondia/run.ps1 -Device emulator-5554`.
La sincronización es transversal al repositorio e independiente de que Muondia
arranque correctamente. El primer lanzador reutiliza el emulador o prepara
el AVD `AI_APPS_Dev` sin ventana; el segundo prepara/reutiliza Dart y
mantiene el Flutter Dev Runner existente.

El registro `.ai-apps/dev-session.log` contiene estados, errores por etapa y
confirmaciones de Hot Reload. Solo conserva mensajes conocidos: no vuelca logs
de la app, excepciones completas, claves, tokens ni defines. Para diagnosticar
un fallo detallado, detén la tarea y ejecuta el lanzador en PowerShell.
El lanzador necesita la clave previamente guardada con DPAPI para este usuario
o una variable de entorno válida; el arranque oculto no solicita credenciales.

Al abrir VS Code, AI-APPS Android recupera los visores de las aplicaciones activas.
El selector múltiple identifica cada aplicación y dispositivo, conserva las otras
pestañas y restaura cada transporte sin duplicarlo. Los comandos explícitos de
arranque y parada controlan sesiones independientes; abrir o cerrar una pestaña
no inicia ni detiene Flutter ni Android. Consulta [la operación multiemulador](../scripts/android/README.md).
Cerrar o reabrir el editor no inicia Flutter, Dart ni Gradle. Un fallo del visor
no afecta a la sesión persistente. Los errores de solicitud se registran en
Output → `AI-APPS Android`; los errores de transmisión, en `Android Emulator`
y en la propia pestaña. La distribución mantenida corrige los dos generadores
de `scid` de EmbeDroid 1.0.2 y conserva identificadores de 31 bits admitidos
por scrcpy. Consulta la [corrección y sus pruebas](../scripts/vscode-android/README.md).
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

Verificación completada el 10 de octubre de 2026: el usuario confirmó dos
cierres y reaperturas completos de VS Code con Muondia visible y funcional,
sin ejecutar Flutter ni detener la tarea. La comprobación posterior confirmó
los mismos procesos de Android, Muondia, Dart y Flutter, sin una nueva
compilación en `dev-session.log`, y Hot Reload automático después de un cambio
Dart temporal restaurado. La ejecución manual independiente de
`flutter run -d emulator-5554` y la restauración de la tarea se habían
comprobado antes de estos ciclos. El diagnóstico previo de EmbeDroid se
conserva como incidencia intermitente; no invalida los dos ciclos confirmados.

---
## COMMIT

.\scripts\sync-dev.ps1

---

## USUARIO H
.\scripts\sync-dev.ps1
.\apps\muondia\run.ps1 -ProbarOnboardingQuiz -Muestras 20

---

## COLA USUARIOS
.\scripts\sync-dev.ps1
.\apps\muondia\run.ps1 -ProbarOnboardingQuiz -Usuarios 20

---

## HOT RELOAD FLUTTER

`apps/muondia/run.ps1` inicia Flutter mediante
`scripts/flutter-dev-runner.dart`. El runner vigila los archivos Dart,
assets de Muondia y las dependencias locales compartidas usadas por la app.

Cuando `git pull` o `scripts/sync-dev.ps1` modifica esos archivos, el
runner agrupa los eventos y solicita automáticamente un Hot Reload incremental
a la sesión Flutter activa. No es necesario pulsar `r` después de cada
sincronización. La vigilancia funciona también en la tarea oculta, sin terminal ni VS Code.

En una ejecución manual en PowerShell, la terminal conserva los atajos: `r` fuerza Hot Reload, `R` hace
Hot Restart y `q` termina la sesión. Los cambios de dependencias, configuración
nativa o `pubspec.yaml` pueden requerir reiniciar la sesión de desarrollo.



## Sincronización continua de `dev`

La sesión general `scripts/start-dev-session.ps1`, lanzada por la tarea
`AI-APPS Development`, inicia `scripts/auto-sync-dev.ps1` en segundo plano
antes de Android y Muondia. El sincronizador no depende del lanzador de ninguna
aplicación. Un bloqueo local evita lanzar más de una instancia.

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

Para el desarrollo cotidiano, Muondia se ejecuta en el AVD local preparado por
AI-APPS. EmbeDroid abre ese emulador dentro del editor mediante
`embedroid.openEmbedded`, el mismo flujo que ya utilizaba el repositorio antes
de pasar temporalmente al Pixel físico.

El rechazo intermitente de identificadores `scid` de 32 bits en EmbeDroid
1.0.2 se confirmó de nuevo a las 14:47 del 10 de octubre de 2026 y se corrigió
en el transporte. `scripts/install-embedroid.ps1` instala la distribución
`magullodev.ai-apps-embedroid` 1.1.0, mantenida en el repositorio con hashes,
constructor de VSIX y pruebas. Su identidad propia evita que una actualización
de la extensión original sobrescriba el arreglo. Recarga VS Code después de
instalarla; Android y Flutter siguen activos.

Las pruebas cubren identificadores límite, 100.000 valores aleatorios, tres
transmisiones reales de diez segundos y reaperturas de un perfil aislado de
VS Code con webviews reales. El [diagnóstico actualizado](../scripts/vscode-android/README.md)
detalla la evidencia y distingue esa validación de una recarga del editor
principal. Una pestaña abierta por sí sola no acredita una transmisión activa.

El objetivo del flujo es: cambios de código → autosync/local → Hot Reload →
visualización inmediata en EmbeDroid → captura desde el PC. El Pixel físico
queda para comprobaciones finales.
