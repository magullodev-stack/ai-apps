# Visualización de Android en VS Code

`extension.js` solicita `embedroid.openEmbedded` sobre `emulator-5554`
al activar el repositorio. La tarea **AI-APPS Development** mantiene Android,
el servicio Dart y Flutter fuera del editor. La integración no compila ni
arranca QuizAI.

## Limitación de EmbeDroid 1.0.2

Diagnóstico del 10 de octubre de 2026 con VS Code 1.141.0 y la extensión
instalada `utpalbarman.embedroid` 1.0.2. Después de este diagnóstico, el usuario
confirmó dos cierres y reaperturas completos con QuizAI visible y funcional,
sin ejecutar Flutter ni detener la tarea. **Los dos ciclos de aceptación están
superados**. Se conserva el diagnóstico del fallo intermitente observado antes;
esta verificación no implica que el transporte de EmbeDroid haya sido corregido.

Una pestaña existente no demuestra que haya una conexión de vídeo activa.
El guard `alreadyOpen` omitiría la apertura para `embedroid.embedded`, pero
VS Code utiliza también el tipo interno `mainThreadWebview-embedroid.embedded`.
La comparación actual no coincide con ese tipo. Véanse las implementaciones
de [los tipos de webview](https://github.com/microsoft/vscode/blob/2a59476c9bfcb90b3ddc372c36762471b7dfad1c/src/vs/workbench/api/browser/mainThreadWebviewPanels.ts)
y de [las pestañas](https://github.com/microsoft/vscode/blob/2a59476c9bfcb90b3ddc372c36762471b7dfad1c/src/vs/workbench/api/browser/mainThreadEditorTabs.ts).

La inspección de `package.json`, `dist/extension.js` y `media/webview.js`
de EmbeDroid instalada encontró:

- No registra `registerWebviewPanelSerializer`: no implementa restauración
  de la conexión de una pestaña tras terminar el proceso del editor.
- No publica un comando de reconexión ni una API exportada para ello.
  **Retry** envía un mensaje interno desde su propia webview.
- `openEmbedded` revela el panel si ya figura en su mapa de vistas, sin
  renovar la transmisión. Cerrar únicamente ese panel y abrirlo de nuevo
  crea otro puente y otra sesión scrcpy; no garantiza que esta sobreviva.
- Genera `scid` mediante `randomBytes(4).toString('hex')`, sin limitarlo a
  31 bits. El [servidor scrcpy 3.2](https://github.com/Genymobile/scrcpy/blob/v3.2/server/src/main/java/com/genymobile/scrcpy/Options.java)
  lo interpreta como un entero Java con signo. Los valores superiores a
  `7fffffff` son rechazados con `NumberFormatException`.

Por tanto, el guard no explica el fallo concreto registrado. Reemplazarlo
por una recreación de pestañas no corrige el fallo del transporte de la
extensión instalada. Se conserva el JavaScript y se documenta la limitación;
no se parchea EmbeDroid ni se añaden esperas o reintentos en AI-APPS.

## Evidencia local

Los registros de VS Code están en `%APPDATA%/Code/logs/`. Las horas siguientes
son Europe/Madrid; el canal Android Emulator guarda las horas en UTC.

| Caso | Resultado registrado |
| --- | --- |
| Reload Window, 13:56 | Transmisión H.264 establecida en el primer intento a las 13:56:53, sin cierre posterior en ese registro. |
| Reapertura completa, 13:58 | Nueva transmisión solicitada. Primer `scid=d41ef4bb` rechazado; segundo intento conectado a las 13:58:37 y cerrado a las 13:58:38. |
| ADB mientras el visor falla | `emulator-5554` conectado, `com.aiapps.quizai` con PID `5478`, `MainActivity` en primer plano. |

El identificador de arranque Android observado fue
`a557f1c5-8ce1-45a2-9fdd-0e1cd1524c9b`. La tarea persistente estaba
`Running`; el último arranque Flutter registrado fue a las 13:52:21.
También existe un fallo del transporte a las 13:01 tras dos identificadores
rechazados, seguido de conexión y cierre: el problema no es exclusivo de
restaurar el editor.

La comprobación aislada del JavaScript con una API VS Code simulada confirmó
que el guard omite el comando con `embedroid.embedded` y lo ejecuta con
`mainThreadWebview-embedroid.embedded`. Es una comprobación de la condición,
no una prueba visual de restauración.

### Cierre de la verificación

El 10 de octubre de 2026, el usuario confirmó que cerró y reabrió completamente
VS Code dos veces: QuizAI apareció y funcionó correctamente en ambas aperturas.
No ejecutó Flutter ni detuvo **AI-APPS Development**. Estos ciclos fueron
realizados y observados por el usuario; el agente comprobó después el estado
de los procesos y los registros, sin cerrar de nuevo el editor.

La comprobación posterior mantuvo los PID ya observados: emulador `22120`,
QuizAI `5478`, servicio Dart `26616`, entrada persistente `25748`, runner `8448`
y Flutter `24348`. Android conservaba su identificador de arranque y QuizAI
estaba en primer plano; `/health` confirmó el servicio Dart. El registro
persistente no contiene nuevos arranques ni compilaciones después de las
13:52:21. Los PID son evidencia de esta comprobación, no valores de configuración.

En la sesión de VS Code `20261010T141931`, EmbeDroid estableció vídeo H.264
en el primer intento a las 14:19:36 Europe/Madrid, sin cierre posterior en el
registro consultado. Un cambio Dart temporal y su restauración generaron Hot
Reload automático completado a las 14:21:41 y 14:21:42, manteniendo el mismo
ejecutor Flutter. El archivo se restauró y `git diff --check` pasó.

La prueba manual independiente `flutter run -d emulator-5554`, el Hot Reload
visual de Dart y assets y la restauración de la sesión persistente ya se habían
completado antes de estos dos ciclos. El informe local actualizado está en
`.ai-apps/dev-session-verification.json`, excluido de Git y sin credenciales.

## Recuperación y alternativa

Para una recuperación manual, usa **Retry** dentro de EmbeDroid. Si no
funciona, cierra solo su pestaña y ejecuta **Android Emulator: Open Embedded
View** sobre el dispositivo existente. No uses **Stop Device**, **Boot** ni
**Cold Boot** para reparar la visualización. Estas acciones manuales no
constituyen una garantía de restauración automática en 1.0.2.

La solución de fondo requiere corregir el transporte en EmbeDroid y ofrecer
restauración o reconexión pública. Cuando haya una versión corregida,
validar primero su API y dos reaperturas completas. Si no ofrece reconexión
pública, recrear únicamente las pestañas EmbeDroid una vez al activar
AI-APPS, usando `tabGroups.close` y después `openEmbedded`.

Mientras tanto, la alternativa de visualización es el cliente oficial
[scrcpy](https://github.com/Genymobile/scrcpy), conectado al emulador ya
existente, en su propia ventana. Si está instalado:

```powershell
scrcpy --serial emulator-5554 --no-audio
```

No necesita iniciar Flutter ni reinstalar QuizAI. No se ha instalado ni
activado esta alternativa durante el diagnóstico.

## Prueba de aceptación

1. Guardar los archivos abiertos y comprobar ADB, PID de QuizAI, identificador
   de arranque Android y PID/hora de inicio del servicio Dart y del runner
   Flutter. Consultar `.ai-apps/dev-session.log`.
2. Cerrar completamente VS Code y confirmar que terminan sus procesos.
   Mantener la tarea persistente activa; no ejecutar otro `flutter run`.
3. Reabrir el repositorio. Confirmar que QuizAI aparece automáticamente,
   que hay vídeo e interacción y que no se muestra un error de transmisión.
4. Repetir otro cierre y reapertura completos. Comprobar en ambos ciclos
   que Android, QuizAI, Dart y Flutter conservan sus procesos y que el
   registro no contiene otra compilación ni un arranque de la aplicación.

Si falla el visor, guardar el resultado y el canal **Android Emulator**.
El mensaje `EmbeDroid abierto` del canal **AI-APPS Android** solo indica que
terminó la solicitud de apertura; no certifica recepción de vídeo.
