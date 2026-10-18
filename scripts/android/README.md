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

La tarea `AI-APPS Development`, instalada por
`scripts/install-dev-session.ps1`, se dispara **al iniciar sesión en
Windows**. Es la única encargada de iniciar Android y Muondia.
VS Code no necesita estar abierto para que se ejecute la aplicación.

Al abrir VS Code, una pestaña restaurada de Muondia espera sin abrir
scrcpy. El Explorador solo inicia el visor cuando la tarea de Windows
está `Running`, el emulador está conectado y Muondia tiene un PID.
Una APK huérfana no cuenta como aplicación activa ni se abre como si
fuera una sesión Flutter vigente. Si la tarea no está ejecutándose,
AI-APPS Android puede solicitar su inicio, sin bloquearlo por un
proceso anterior: la propia tarea decide si ese proceso es suyo o de F5.
Una pestaña cerrada manualmente permanece cerrada hasta elegirla
desde el selector; otras sesiones se abren bajo demanda.

El visor puede reconectarse manualmente sin reiniciar Android ni Flutter.
El sondeo existente de AI-APPS Android cada cinco segundos detecta
cuándo termina el arranque de la tarea e inicia el visor una sola vez.
EmbeDroid no duplica el sondeo ni añade reintentos automáticos propios
a los que trae scrcpy.

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

La tarea vuelve a intentar iniciar Flutter con espera progresiva (15–60 s)
si se produce un fallo temporal, sin cerrar el emulador ni ocupar un Flutter
ajeno. AI-APPS Android, mientras VS Code está abierto, recupera una tarea
que dejó de estar activa mediante su sondeo habitual (30 s como mínimo
entre intentos), pero respeta una parada explícita y una sesión F5.
No se necesita abrir PowerShell para cada cambio visual.

Estas mejoras requieren que la sesión ejecutora y la extensión carguen
su versión actualizada; los procesos ya abiertos no actualizan su propio
código de supervisión solo porque Git sincronice los archivos.

## Recuperación del AVD cuando ADB pierde emulator-5554

La tarea persistente de Windows conserva la propiedad de Muondia incluso
sin VS Code abierto. `flutter-dev-runner.dart` comprueba ADB cada cinco
segundos; únicamente después de **tres ausencias consecutivas** termina
el Flutter que él mismo inició y devuelve a `run.ps1` el código 88.
`run.ps1` no intenta `adb connect emulator-5554` (no es un dispositivo TCP):
devuelve el control a `start-dev-session.ps1`, que prepara de nuevo Android.

`start-ai-apps-android.ps1` espera primero una ventana breve por cortes
transitorios. Si detecta el AVD reservado detenido o offline, comprueba que
el proceso sea un `emulator.exe`/QEMU correspondiente **simultáneamente**
a `AI_APPS_Dev` y al puerto 5554. Antes de terminarlo verifica de nuevo
su identidad, PID y fecha de creación; espera su salida antes de arrancar
otro. Un proceso de propiedad desconocida que ocupe el puerto bloquea el
arranque: **no** se mata ningún otro AVD, no se reinicia el servidor ADB
global y no se toca F5. Si el proceso ya no existe, inicia el AVD reservado
incluso si ADB conserva momentáneamente la fila `offline`.

La extensión AI-APPS Android detecta la desconexión y reconecta el visor
en su sondeo habitual cuando reaparecen dispositivo y aplicación. La
recuperación no necesita cerrar/reabrir VS Code ni pulsar «Try again».
La detección requiere que la tarea de Flutter cargue la versión nueva del
runner y los scripts actualizados; no puede darse por validada sin probar
una desconexión real en Windows.

## Recuperación de actualizaciones Flutter

Las modificaciones sincronizadas por Git se detectan además mediante
una revisión periódica del commit HEAD. El monitor de archivos y ese respaldo
de Git utilizan el mismo clasificador de cambios: Dart de interfaz pide
Hot Reload; main.dart o recursos existentes piden Hot Restart; recursos
añadidos/eliminados, pubspec o código nativo piden recompilación. Se aplica
la acción más fuerte del conjunto, sin duplicar los eventos ya procesados
por el monitor. Los archivos ajenos a la aplicación no la actualizan.

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
