# Sesiones Android independientes

AI-APPS Android identifica aplicaciones mediante su registro local y muestra
cada emulador con EmbeDroid dentro de VS Code. Android, Dart y los procesos
Flutter se ejecutan fuera del editor. Abrir, cerrar o reconectar un visor no
reinicia ninguna aplicación.

## Instalación

```powershell
.\scripts\install-embedroid.ps1
```

Tras instalar, recarga VS Code. La integración recupera la sesión activa
de Muondia en `emulator-5554`; otras aplicaciones registradas pueden
abrirse desde el selector **AI-APPS Android**.

Muondia utiliza la tarea persistente `AI-APPS Development`. Su identificador,
paquete `com.aiapps.muondia` y AVD `AI_APPS_Dev` están reservados.
No ejecutes una segunda instancia Flutter sobre ese dispositivo. F5 es solo
una alternativa de depuración: su preparación se niega mientras la tarea esté
activa o queden procesos Flutter en `emulator-5554`; nunca los detiene.

## Otras aplicaciones Flutter

El registro permite conectar proyectos Flutter independientes con su propio
AVD, serial y paquete Android, sin compartir el dispositivo de Muondia.
Ejemplo para una aplicación real ya existente:

```powershell
.\scripts\android-session.ps1 -Action Register `
  -AppId app-demo -Label 'App Demo' `
  -Serial emulator-5556 -AvdName AI_APPS_Demo `
  -ProjectPath 'C:\ruta\app-flutter' -PackageName dev.example.demo
.\scripts\android-session.ps1 -Action Start -AppId app-demo -Serial emulator-5556
.\scripts\android-session.ps1 -Action List
.\scripts\android-session.ps1 -Action Stop -AppId app-demo -Serial emulator-5556
```

El ejemplo no registra ni instala ninguna aplicación por sí mismo. Cada
sesión queda aislada por dispositivo y AVD; el controlador rechaza el uso
compartido de `emulator-5554` y dos procesos Flutter sobre un dispositivo.

Para retirar el registro de una aplicación detenida, utiliza
`-Action Unregister`. Esta operación no borra el código, el AVD ni otros
archivos. Android mantiene estados y registros en `.ai-apps/android/`,
fuera de Git.

## Visores y recuperación

VS Code recupera Muondia al abrir el repositorio. Un visor cerrado
manualmente permanece cerrado hasta que se elige desde el selector;
otras sesiones se abren bajo demanda. EmbeDroid guarda únicamente el
serial del dispositivo y consulta la identidad actual de la aplicación
en el registro. No persiste nombres antiguos.

El visor se reconecta sin reiniciar Android ni Flutter. Si está detenida,
la tarea de desarrollo se solicita al Programador de tareas; la extensión
no abre APK antiguas ni inicia otro `flutter run` por su cuenta.
El sondeo cada cinco segundos detecta cambios de estado.

## Verificación

```powershell
.\scripts\embedroid\test.ps1
.\scripts\android\test.ps1
```

Las pruebas simulan el registro persistente, la exclusividad de AVD,
los arranques concurrentes, las paradas, la reconexión de visores, la
restauración y la recuperación de Muondia. Para verificar dos aplicaciones
reales se dispone de `scripts/android/host-test.ps1`, que exige
`-AppId`, `-Serial` y `-Label` de una segunda aplicación activa.
No crea una segunda aplicación.

## Recuperación de un Flutter persistente huérfano

La tarea de Windows puede haber terminado mientras sigue vivo un Flutter
anterior de Muondia. Git puede continuar sincronizando cambios, pero la tarea
se negaba a arrancar porque el dispositivo aparecía ocupado. Esto explica
por qué una nueva imagen podía no llegar a la aplicación aunque ya estuviese
en dev.

Al iniciarse, scripts/start-dev-session.ps1 consulta primero la ocupación
de emulator-5554. Si hay un proceso, delega en la acción Recover de
scripts/android/task-control.ps1, que utiliza el clasificador puro
scripts/android/flutter-ownership.ps1:

- free: no hay Flutter ocupando el emulador; arranque normal.
- owned: TODOS los procesos que ocupan el dispositivo se identifican
  con el runner o los defines propios de la tarea de ESTE repositorio;
  se verifica PID, fecha y comando otra vez, se liberan esos procesos y
  se inicia una sola sesión Flutter nueva, sin cerrar Android.
- foreign: aparece F5, otra sesión o un proceso ambiguo; no se termina
  ningún proceso y no se inicia un Flutter competidor.

Recover no llama a Stop-ScheduledTask: es seguro invocarlo desde la
propia tarea durante su arranque. Stop conserva la parada deliberada y
la cesión controlada a F5. La recuperación queda reflejada en
.ai-apps/dev-session.log sin nombres de proceso, argumentos, tokens ni
otros datos sensibles.

Prueba de clasificación sin Android ni procesos reales:
powershell -NoProfile -File scripts/android/flutter-ownership.test.ps1.
El contrato de arranque también la ejecuta desde
node scripts/android/startup-contract-test.cjs en Windows.

Esta reparación evita que un proceso huérfano bloquee el SIGUIENTE
arranque. No permite determinar retrospectivamente por qué terminó la
tarea anterior y no constituye un supervisor continuo de tareas detenidas;
ese estado sigue siendo observable mediante Get-ScheduledTaskInfo.

## Recuperación de actualizaciones Flutter

El propietario de las sesiones Flutter es `scripts/flutter-dev-runner.dart`,
no VS Code. Agrupa los cambios detectados por los watchers, mantiene **una
sola petición `app.restart` en vuelo** y utiliza Hot Reload para cambios
normales y Hot Restart para imágenes. Ante un Hot Reload rechazado por
Flutter, solicita automáticamente **un Hot Restart de la misma sesión**,
sin crear un segundo `flutter run` ni intervenir en ADB.

Si Hot Restart también falla, el runner **no entra en un bucle**: registra
un código de fallo seguro y espera nuevos cambios. Si Flutter deja de
responder a una petición durante dos minutos, el runner termina únicamente
el árbol del Flutter que él mismo lanzó y entrega el relanzamiento al
controlador persistente `apps/muondia/run.ps1` (salida 86). No se reinicia
el emulador ni se eliminan datos.

`scripts/start-dev-session.ps1` registra el tipo y código de error, la
recuperación solicitada y su resultado en `.ai-apps/dev-session.log`
sin volcar salida arbitraria de Flutter, URL ni secretos. El código de
fallo puede permitir distinguir errores de fuentes frente a fallos de
protocolo; no implica que todos ellos se puedan solucionar automáticamente.

Prueba del protocolo sin dispositivo ni segundo Flutter:
`dart scripts/flutter-dev-runner-machine-test.dart`.
Simula fallo de Reload, recuperación con Restart, fallo de Restart sin
bucle y bloqueo de respuesta con vigilancia temporal. Verificar también
una edición real en Windows antes de dar el problema por resuelto.
