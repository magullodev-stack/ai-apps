# Visualización de Android en VS Code

## Explorador de experiencias

El nodo «Explorador de experiencias» se muestra dentro del árbol **AI-APPS Android** que ya está instalado (ID `aiAppsAndroid.sessions`), sin depender de registrar otra vista. Descubre los catálogos definidos por las aplicaciones en `lib/app/development/experiences.json`; no deduce pantallas a partir de assets o archivos Dart. Una entrada abre el widget Flutter real con un estado de desarrollo.

Para evitar solapamientos de etiquetas al desplegar el árbol, el sondeo
de sesiones cada cinco segundos actualiza los nodos **solo** si cambia
el estado de una sesión o la revisión del catálogo; los clics y la
navegación no invalidan innecesariamente el árbol. Esta regla se
comprueba en las pruebas de la extensión.

El comando `aiAppsAndroid.preview` valida la experiencia solicitada y envía un intent `<package>.DEV_OPEN_EXPERIENCE` al emulador asignado. No inicia sesiones Flutter, no borra datos y no dispara IA. Muondia expone Auth, Loading (inicio/en curso/finalización), Test con preguntas de prueba y Home. El arranque de Muondia en debug muestra Auth simulado para evitar peticiones IA automáticas; F7 hace lo mismo. Tras sincronizar, recargar VS Code una vez. Ejecutar las pruebas `node scripts/vscode-android/explorer.test.cjs` y `node scripts/vscode-android/test.cjs`.


AI-APPS Android gestiona un visor por aplicación y dispositivo mediante
EmbeDroid mantenido 1.1.0. Incluye selección múltiple; la vista de Muondia se
recupera al abrir VS Code. Otras aplicaciones registradas pueden abrirse
desde el selector. Consulta [sesiones, configuración y pruebas](../android/README.md).
La tarea **AI-APPS Development** mantiene Android, Dart y Flutter fuera del
editor. Al abrir VS Code se solicita la tarea si estaba detenida, incluso si
Android conserva una APK antigua abierta; abrir o cerrar un visor no ejecuta
directamente Flutter ni una APK instalada.

## F7: volver a Auth en desarrollo

La integración AI-APPS Android registra F7 como comando
`aiAppsAndroid.auth`, habilitado solo cuando el proyecto establece
`aiAppsAndroid.devShortcuts`. El comando entrega un intent explícito
`com.aiapps.muondia.DEV_SHOW_AUTH` a la actividad de Muondia en
`emulator-5554`. Android lo comunica mediante el canal
`muondia/development` a Flutter, sin depender del transporte de teclado
de EmbeDroid, sin controlar Flutter ni reiniciar el emulador. Flutter
atiende el evento únicamente en debug, sin cerrar Firebase ni eliminar datos.
La actividad Android también lo rechaza fuera de una compilación depurable.
Tras sincronizar la extensión enlazada, recargar VS Code una vez para
registrar el nuevo comando y su atajo.

## Corrección del transporte

EmbeDroid 1.0.2 generaba `scid` con `randomBytes(4).toString('hex')`
en el constructor y en cada arranque. El servidor scrcpy 3.2 interpreta ese
argumento con `Integer.parseInt(value, 16)`: acepta identificadores de 31
bits. El bit de signo provocaba `NumberFormatException` y la salida con
código 1. Véase [Options.java de scrcpy 3.2](https://github.com/Genymobile/scrcpy/blob/v3.2/server/src/main/java/com/genymobile/scrcpy/Options.java).

El registro actual confirma la causa el 10 de octubre de 2026 a las 14:47
Europe/Madrid (12:47 UTC), en
`%APPDATA%/Code/logs/20261010T141931/window1/exthost/output_logging_20261010T144729/3-Android Emulator.log`:

| Intento | scid rechazado | Resultado |
| --- | --- | --- |
| 1 | `cf1b8d37` | NumberFormatException, código 1 |
| 2 | `efb79b97` | NumberFormatException, código 1 |
| 3 | `a5439c11` | NumberFormatException, código 1 |
| 4 | `d47f445a` | NumberFormatException, código 1 |

Los cuatro valores superan `7fffffff`. La gestión de pestañas no explica
estas excepciones. Se corrigen los dos generadores dentro del transporte
EmbeDroid, sin añadir esperas ni reintentos.

La distribución mantenida `magullodev.ai-apps-embedroid` 1.0.3 deriva de
1.0.2 y está versionada en [scripts/embedroid/](../embedroid/README.md).
El generador limita a 31 bits y conserva ocho dígitos hexadecimales para
que coincidan el socket ADB y el nombre generado por scrcpy. La versión 1.1.0
conserva esta corrección y amplía las pestañas con identidad y serialización,
sin modificar el transporte scrcpy ni los archivos upstream.

## Instalación y actualizaciones

`scripts/install-embedroid.ps1` construye y comprueba el VSIX, lo instala,
retira la extensión original para evitar comandos duplicados y actualiza el
enlace de AI-APPS Android. Después recarga o reabre VS Code. No detiene Android
ni Flutter.

`scripts/install-vscode-android.ps1` instala solo el enlace de la integración;
para preparar ambos componentes utiliza:

```powershell
.\scripts\install-embedroid.ps1
```

La identidad propia impide que Marketplace sobrescriba el arreglo con una
actualización de `utpalbarman.embedroid`. Los archivos originales, sus
hashes, el generador, el constructor del VSIX y las pruebas están en Git.
No se edita el bundle instalado. Si al restaurar una pestaña sigue apareciendo
un nombre de una aplicación retirada (por ejemplo, `QuizAI - emulator-5554`),
verifica que estén instaladas y activas las extensiones mantenidas, ejecuta de
nuevo `scripts/install-embedroid.ps1` y **recarga VS Code**. La identidad actual
es `Muondia · emulator-5554`, obtenida del registro, no del estado del visor.
Al restaurar `emulator-5554` se asigna directamente el título
`Muondia · emulator-5554`, sin pasar por `Android` y aunque falle la conexión
al vídeo. No se borra el AVD, la APK ni el estado de la aplicación.
La actualización upstream exige importar,
revisar y validar deliberadamente otra versión; el constructor rechaza un
paquete original que no coincida con los hashes fijados. El repositorio
upstream indicado por el paquete devolvió 404 durante esta intervención;
no se ha presentado un PR al autor.

## Validación del 10 de octubre de 2026

- Límites `00000000`, `7fffffff`, `80000000` y `ffffffff`, más 100.000
  identificadores aleatorios dentro del intervalo admitido.
- Clase real del bundle: constructor y arranque usan el generador corregido;
  el argumento del servidor y el socket ADB coinciden.
- Servidor incluido: el identificador original `ffffffff` reproduce la
  excepción y el código 1. Con el arreglo, tres transmisiones H.264 sostienen
  vídeo diez segundos cada una, sin errores y conectadas al primer intento.
- Webviews reales en un perfil aislado de VS Code: vídeo H.264, sin excepciones
  ni fallos de arranque. La prueba reproducible `host-test.ps1` abre dos
  procesos independientes sobre el mismo perfil y dos vistas en cada uno.
- Android conserva su identificador de arranque y Muondia su PID. La tarea
  persistente y los procesos Dart/Flutter siguen activos, sin nueva compilación.

Los informes y registros de estas pruebas están en `.ai-apps/embedroid/`,
excluidos de Git. Las reaperturas aisladas no equivalen a afirmar que se ha
recargado el editor principal del usuario. La nueva distribución instalada
se carga al recargar o reabrir ese editor.

La corrección resuelve el rechazo de `scid`; otros cierres con código 0 o
255 requieren sus propias evidencias. Una pestaña abierta y el mensaje
`EmbeDroid abierto` solo acreditan la solicitud; el canal **Android Emulator**
debe confirmar `streaming h264` y `streaming established on attempt 1`.

## Comprobación en el editor principal

1. Recargar o reabrir VS Code, manteniendo **AI-APPS Development** activa.
2. Comprobar vídeo e interacción y el canal **Android Emulator**.
3. Repetir una reapertura y comprobar que Android, Muondia, Dart y Flutter
   conservan sus procesos y que `dev-session.log` no registra otra compilación.

No uses **Stop Device**, **Boot** ni **Cold Boot** para reparar el visor.
