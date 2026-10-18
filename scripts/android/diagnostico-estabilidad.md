# Investigación del entorno Windows — 18 de octubre de 2026

## Causas observadas

1. **Crash nativo de Android, anterior a la recuperación.** Windows registra
   eventos Application 1000/1001 de `qemu-system-x86_64-headless.exe`,
   excepción `0xc0000005`, módulo `unknown`. Por ejemplo, a las 18:32:44,
   18:35:47, 18:38:25 y 18:42:41. Después se cierran los transportes de
   scrcpy y Flutter, ADB pasa a offline y la tarea compila otra APK.
   No hay modificaciones de archivos entre esos ciclos. También existen
   crashes de este ejecutable el 11 de octubre: no se atribuye el fallo
   nativo exclusivamente a los scripts añadidos el día 18.
2. **Recuperación demasiado amplia.** Los cambios `f795ef6`, `29f937b`,
   `217b49a` y `f99adbf` conectaron ausencias ADB/pérdida de VM con cierre
   de Flutter y recuperación rápida del AVD. La ausencia en ADB no prueba
   que QEMU esté muerto. El detector omitía las variantes `-headless.exe`.
   VS Code añadía otra vía de arranque de la tarea desde su sondeo.
3. **Cambios aplicados más de una vez.** El watcher actualizaba una edición
   local; seis segundos después, autosync la confirmaba y el monitor Git
   volvía a solicitar una actualización por los mismos bytes. Además,
   delete/create de Windows al sustituir un PNG se interpretaba como baja
   real y provocaba una recompilación innecesaria.
4. **Errores de compilación convertidos en reinicios.** `f077226` solicitaba
   reconstrucción tras fallar Reload y Restart, aunque la edición fuera
   temporalmente inválida. Las rutas relativas del propio runner también
   se clasificaban como Reload, impidiendo cargar correctamente su arreglo.
5. **Distribución del visor distinta del código revisado.** La extensión
   instalada era EmbeDroid 1.1.0; el repositorio construía 1.1.2. La copia
   instalada no recibe cambios por Git. La integración AI-APPS Android sí
   está enlazada al repositorio, pero el JavaScript ya cargado permanece
   en memoria hasta una nueva activación del editor.

`RuntimeException` era una categoría PowerShell, no el diagnóstico del crash
QEMU. Los eventos de Windows permiten establecer el orden causal.

## Aislamiento del backend gráfico

Mismo AVD `AI_APPS_Dev`, Android 36, emulador 37.2.12, WHPX disponible.
No se borraron datos ni se recreó el AVD.

| Prueba | Resultado observado |
| --- | --- |
| Arranque original, Vulkan/Lavapipe | Crashes repetidos; ADB y ambos transportes caen después. |
| Arranque frío `-no-snapshot`, 18:46:26 | Otro crash idéntico a las 18:48:40, tras una transmisión real. Quick Boot por sí solo no explica el problema. |
| Arranque frío `-feature -Vulkan`, 18:49:32 | Android conserva su arranque durante las pruebas de vídeo, sincronización y compilaciones solicitadas. OpenGL ES utiliza SwiftShader. |

El lanzador conserva `-no-snapshot -feature -Vulkan` para evitar la ruta
gráfica que reproduce el fallo y no reintroducir un estado Vulkan guardado.
No se afirma haber identificado la instrucción nativa defectuosa: el evento
no proporciona símbolos. Es una mitigación comprobada de esa ruta gráfica.
Referencias: [diagnóstico oficial](https://developer.android.com/studio/run/emulator-troubleshooting)
y [limitaciones de snapshots con software rendering](https://developer.android.com/studio/run/emulator-snapshots).

## Propiedad y corrección

- La tarea de inicio de sesión Windows sigue siendo el único supervisor:
  `start-dev-session.ps1` → preparación Android → `run.ps1` → runner Dart
  → `flutter run --machine`. El servicio Dart se reutiliza.
- Autosync permanece independiente y usa su bloqueo exclusivo existente.
  Se pausó durante las ediciones; no se añadió otro sincronizador.
- Una VM conectada no se termina porque una consulta ADB falle. Perder la VM
  con Android online recupera solo Flutter. El preparador conserva QEMU vivo
  y únicamente puede liberar un wrapper propio huérfano, revalidando PID,
  fecha, argumentos y ausencia de una cesión F5.
- Watcher y monitor Git comparten clasificación y contenido aplicado. Los
  bytes rechazados esperan una edición nueva; un error de compilación no
  solicita Gradle en bucle. Cada relanzamiento repone `adb reverse`.
- El visor reconecta únicamente su transporte. La extensión de VS Code no
  vuelve a iniciar la tarea desde su sondeo. Se instaló el VSIX 1.1.2.

## Verificación

- Suite del protocolo con runner real, Flutter simulado y Git temporal;
  clasificación Unicode, cola, contenido rechazado y deduplicación.
- Fixtures PowerShell del preparador: QEMU/headless vivo, ADB transitorio,
  wrapper huérfano, PID reutilizado, F5 y puerto ajeno.
- Suites Android, EmbeDroid, integración VS Code, experiencias e inspector
  de assets; análisis Dart y `git diff --check`.
- Tres streams reales de diez segundos: 279, 315 y 301 frames H.264,
  conexión al primer intento y mismos PID de Muondia/arranque Android.
  Dos reaperturas de un perfil aislado de VS Code, con dos webviews por ciclo.
- Edición Windows a las 18:59:42: un Reload a las 18:59:43 y publicación
  automática `ca4e3d5`. Restauración mediante API GitHub `68968b3`: recepción
  automática a las 19:00:14 y un Reload a las 19:00:15. Capturas antes/después
  acreditan el texto temporal y su restauración con los mismos procesos.
- Alta remota de un PNG (`3d51308`): recompilación e inclusión comprobada
  en la APK. Sustitución (`942bb22`): visible en captura; detectó la necesidad
  de agrupar delete/create. Retirada/restauración (`c707275`): nueva APK sin
  el PNG temporal y aplicación idéntica al código y recursos originales.

Las evidencias completas permanecen locales en `.ai-apps/`: logs sanitizados,
capturas `flow-*.png`, resultados de transporte/host EmbeDroid y muestreos de
PID/arranque. No se publican tokens, defines, credenciales ni logs arbitrarios.

La API nativa `computer-use` no pudo conectar con Windows. Se verificó vídeo
real en hosts aislados y reconexión del editor principal por su log; no se
confunde instalar 1.1.2 con haber recargado el host principal, que seguía
ejecutando 1.1.0 durante esta comprobación. No se termina ese host, que aloja
también Codex. La nueva versión se cargará en una siguiente activación.
