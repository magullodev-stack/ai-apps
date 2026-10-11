# Sesiones Android independientes

AI-APPS Android mantiene un registro local de aplicaciones y dispositivos.
EmbeDroid muestra un visor por sesión; Android y Flutter viven fuera de VS Code.
Abrir, cerrar o reconectar una pestaña solo afecta a su vídeo. La integración
no fija un máximo de pestañas; los recursos del equipo y los puertos de Android
limitan los emuladores disponibles.

## Instalación y selector

```powershell
.\scripts\install-embedroid.ps1
```

Instala EmbeDroid mantenido 1.1.0 y AI-APPS Android 0.2.0. Recarga o reabre
VS Code para cargar ambas versiones; Android, Flutter y la tarea continúan.
El árbol **AI-APPS Android** aparece en el Explorador. La barra **Android** y
**AI-APPS Android: Seleccionar visores** permiten seleccionar varias sesiones.
Cada pestaña muestra la aplicación y el serial. Las sesiones adicionales se
abren en un grupo contiguo para ver los emuladores a la vez; puedes reagruparlas.

Al abrir el repositorio, recupera las aplicaciones activas. Una apertura repetida
revela la pestaña existente. La [serialización de webviews de VS Code](https://code.visualstudio.com/api/extension-guides/webview#serialization)
conserva su identidad y restaura cada transporte. Las carreras de restauración
eliminan únicamente duplicados del mismo dispositivo, sin cerrar otras pestañas.
El sondeo cada cinco segundos detecta sesiones iniciadas desde PowerShell y
reconecta un visor existente tras perder su dispositivo.

Cerrar una pestaña manualmente la mantiene cerrada durante esa sesión; puedes
reabrirla desde el selector. Al reabrir VS Code se recuperan las apps aún activas.
**Reconectar visor** afecta solo al elegido. El arranque del editor no inicia
Flutter, servicios, tareas ni emuladores. Se requiere un workspace de confianza.

## QuizAI y sesiones nuevas

`quizai@emulator-5554`, su AVD `AI_APPS_Dev` y su identificador quedan reservados.
La tarea **AI-APPS Development** conserva configuración, arranque automático,
servicio Dart, Hot Reload y sincronización. **Iniciar sesión** y **Detener
aplicación** son acciones explícitas, independientes del visor. Para QuizAI
usan la tarea existente y su runner identificado; la parada no mata el servicio
Dart, la sincronización ni Android. Si quedan runners fuera de la tarea, el
arranque exige recuperar la sesión antes de crear otro Flutter.

El selector incluye **Registrar aplicación Flutter**. También hay CLI:

```powershell
.\scripts\android-session.ps1 -Action Register `
  -AppId lab-counter -Label 'Lab Counter' `
  -Serial emulator-5556 -AvdName AI_APPS_Lab_Counter `
  -ProjectPath 'C:\ruta\proyecto-flutter' -PackageName dev.example.counter
.\scripts\android-session.ps1 -Action Start -AppId lab-counter -Serial emulator-5556
.\scripts\android-session.ps1 -Action List
.\scripts\android-session.ps1 -Action Stop -AppId lab-counter -Serial emulator-5556
```

`ProjectPath` puede apuntar a una app Flutter con Android creada por agent-lab,
por ejemplo bajo `agent-lab/runs/<ejecución>/workspace/`. Debe contener
`pubspec.yaml`, y su `applicationId` debe coincidir con `PackageName`. El ejemplo
Python de agent-lab no es Android. Registrar no ejecuta código; **Start** sí.

Cada sesión tiene su propio AVD y serial; se rechazan dispositivos o AVD
compartidos. Flutter usa un puerto de consola par entre 5556 y 5682. El preparador
reutiliza el AVD o lo crea con la imagen instalada `android-36/google_apis_playstore/x86_64`;
no descarga SDK ni inicia IA. Sin parámetros conserva `AI_APPS_Dev` y
`emulator-5554`, como antes.

El worker oculto de cada app mantiene un lease exclusivo, fuera del editor.
Reutiliza `flutter-dev-runner.dart`, `flutter run --machine` y Hot Reload.
Los archivos generados `android/local.properties` y `android/.gradle/` no
cancelan la vigilancia ni solicitan reinicios. Cuando hay cambios nativos reales,
el runner termina su árbol Flutter completo en Windows (wrapper e hijos),
permitiendo que el worker reinicie y recupere la vigilancia sin procesos huérfanos.
Las sesiones nuevas usan `--no-dds` para conectar directamente al VM Service:
DDS rechazaba su conexión local durante la validación. Esta opción es optativa
en el runner; los argumentos originales de QuizAI permanecen iguales. El modo
directo no ofrece las funciones DevTools dependientes de DDS. Credenciales de
IA/Codex no se heredan y los defines de las sesiones nuevas son vacíos.

**Stop** envía un token al worker, que termina únicamente su árbol Dart/Flutter
y hace `am force-stop` sobre su paquete y dispositivo. El AVD queda encendido.
Durante el arranque cancela la espera sin detener Android. Tras una salida
anómala, rechaza matar un PID sin verificar o iniciar otro Flutter en un
dispositivo ocupado. Consulta los logs para recuperar un lease abandonado.
**Unregister** retira solo el registro de una sesión detenida, sin borrar AVD,
proyecto ni logs. Rechaza QuizAI, leases existentes y procesos Flutter o apps
activas; reserva un lease durante la retirada para evitar arranques concurrentes.
Usa `-Action Unregister -AppId <id> -Serial <serial>`.

agent-lab usa este contrato mediante su [adaptador por experimento](../../agent-lab/README.md#flutter-y-android-por-experimento):
registra e inicia Flutter entre iteraciones, conserva la asociación y comprueba
Hot Reload. Su eliminación detiene y retira solo las sesiones de sus workspaces.

`-Kind external` permite registrar una app cuyo ciclo de vida gobierna otra
herramienta: solo se visualiza; su propietario controla arranque y parada.
Usa el tipo `flutter` para el control integrado.

## Captura de una aplicación experimental

```powershell
.\scripts\android-session.ps1 -Action Capture -AppId lab-counter -Serial emulator-5556
```

Devuelve JSON con archivo PNG privado, SHA-256, dimensiones e identidad del
propietario. Es una operación de lectura: no inicia Flutter, enfoca ventanas ni
interactúa con Android. Exige una sesión `flutter` independiente activa, lease
y token estables; rechaza la sesión de desarrollo y dispositivos reservados.
Comprueba paquete enfocado/reanudado, PID, AVD y boot ID antes y después de
la captura binaria. Ante un cambio o una aplicación ajena, falla sin conservar
sus píxeles. Los PNG confirmados se guardan en `sessions/<id>/captures/`.

agent-lab copia y valida la captura dentro del ciclo y la entrega como adjunto
multimodal al agente nativo de ChatDev; conserva observación o fallo explícito.
Consulta su [historial visual](../../agent-lab/README.md#percepción-visual-de-android).
Las regresiones de `capture-test.cjs` forman parte de `test.ps1` y no usan ADB real.

## Estado y verificaciones

El registro `.ai-apps/android/sessions.json` y `sessions/<appId>@<serial>/`
quedan ignorados en Git. Cada sesión conserva `state.json`, `lease.json`,
peticiones `<token>.stop.json`, y logs `flutter.*.log` y `worker.*.log`. No
almacenan credenciales. Un registro inválido se notifica sin cerrar los visores.

```powershell
.\scripts\embedroid\test.ps1
.\scripts\android\test.ps1
```

Las pruebas offline ejercitan el manager del bundle, el controlador del editor
y el runner Dart con Flutter simulado. Cubren registro, exclusión, arranques
concurrentes, parada independiente, leases obsoletos, restauración, reconexión,
cierre manual, selección múltiple y compatibilidad de QuizAI. Ejercitan 123
registros y 150 vistas sin máximo fijo.

`host-test.ps1` admite `-AppId`, `-Serial`, `-Label` y `-RuntimeName` para
validar cualquier sesión Flutter experimental en un perfil propio. Por defecto
requiere QuizAI activa y un registro `lab-validation`, etiqueta
`Lab validation`, en `emulator-5556`. La app secundaria debe repintar periódicamente.
Usa dos reaperturas normales de un perfil aislado de VS Code y un controlador
temporal para comprobar vídeo realmente renderizado y persistencia. No recarga
el editor principal. Los informes quedan en `.ai-apps/android-host/`:

```powershell
.\scripts\android\host-test.ps1
```

Validación real del 11 de octubre de 2026: dos AVD y aplicaciones simultáneos,
dos pestañas con frames renderizados, reconexión y cierre solo del visor
secundario, y segunda reapertura con dos paneles deserializados sin duplicados.
Se comprobaron Hot Reload, parada y reinicio independientes de la app secundaria.
Android conservó su boot ID, QuizAI su PID y trece procesos persistentes previos
siguieron activos. La tarea continuó `Running` y `dev-session.log` no añadió
compilaciones de QuizAI. Su parada se verificó offline; no se interrumpió la
aplicación principal para probar ese comando.
