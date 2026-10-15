# Visualización de Android en VS Code

## Explorador de experiencias y sesiones

**AI-APPS Android** muestra directamente las aplicaciones en ejecución.
La fila «Muondia · emulator-5554» es el único nodo raíz habitual y, al
desplegarla, aparecen sus experiencias: **Auth**, **Primera experiencia**
(Loading del robot y Test de bienvenida) y **Home**. Loading se despliega
en Inicio, En curso y Finalización. No se crean filas duplicadas
«Explorador de experiencias» ni «Muondia», ni carpetas «Acceso» o
«Aplicación» para una sola experiencia.

Los laboratorios `offline`/`failed` permanecen registrados, pero **no
se muestran en el árbol de trabajo**. Los comandos de administración
`AI-APPS Android: Iniciar sesión`, `Detener aplicación` y
`Seleccionar visores` siguen disponibles en la paleta de comandos.
El botón de visualizar sesión sigue disponible en el menú contextual de
las aplicaciones. No se borran AVD, sesiones, archivos ni datos.

El catálogo de experiencias se define en cada aplicación, en
`lib/app/development/experiences.json`. No se infieren experiencias de
assets o archivos Dart. Los grupos con una sola experiencia se muestran
directamente bajo su aplicación; los que contienen varias mantienen
su agrupación.

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

## Inspector visual integrado en las experiencias

El inspector visual **no tiene una carpeta propia**. En AI-APPS Android
cada imagen aparece directamente bajo la experiencia de UI que la utiliza:
`Muondia → Auth → Estrellas.png`, `Muondia → Home → ...` o
`Muondia → Primera experiencia → Loading del robot → ...`.
Loading conserva sus estados Inicio, En curso y Finalización al mismo nivel
que sus imágenes. Auth y Home mantienen su comando para abrir la vista previa
y ofrecen una flecha para desplegar sus recursos. No hay carpetas
«Capas e imágenes», «auth» ni «home» intermedias.

Cada aplicación declara una vez qué carpetas de recursos pertenecen a
cada experiencia mediante el campo opcional `assetDirectories` del
catálogo `lib/app/development/experiences.json`:

```json
{
  "id": "auth",
  "label": "Auth",
  "group": "Acceso",
  "assetDirectories": ["assets/auth"],
  "states": [{"id": "inicio", "label": "Vista inicial"}]
}
```

Las imágenes PNG, JPG y WebP se descubren automáticamente dentro de las
carpetas declaradas, sin mantener listas de archivos. Cada carpeta pertenece
a una sola experiencia; el catálogo rechaza carpetas solapadas para
evitar que una operación de UI afecte a varias pantallas. Una experiencia
sin imágenes no muestra nodos artificiales.

La capacidad Flutter vive en
`shared/ui/lib/src/development/visual_asset_inspector.dart`, instalada una
única vez por aplicación con `AiAppsVisualAssetScope` y
`AiAppsVisualAssetController.connectDebugChannel()`. La orden Android
`<applicationId>.DEV_ASSET_VISIBILITY` solo se atiende en compilaciones
debug. Las imágenes obtenidas de `rootBundle` explícito, plugins externos
o la red no atraviesan el `DefaultAssetBundle` y necesitan adaptadores.

Pruebas: `node scripts/vscode-android/explorer.test.cjs`,
`node scripts/vscode-android/asset-inspector.test.cjs`,
`node scripts/vscode-android/test.cjs`.

## Ojo rápido y menú contextual de recursos

Cada imagen ofrece un **ojo a la derecha** al pasar el ratón: ojo abierto
para ocultarla, ojo tachado para mostrarla. Pulsar el nombre abre el PNG,
no modifica la visibilidad. El botón derecho permite **Sustituir imagen…**
(seleccionar otra del mismo formato, conservando nombre y posición) y
**Eliminar imagen…**. La sustitución pide confirmación, comprueba el formato
y sobrescribe únicamente el PNG existente; Flutter lo detecta.

**Eliminar imagen…** analiza primero el código. Solo retira un elemento
visual si existe una asociación declarativa inequívoca con ese recurso,
el PNG no aparece en otras expresiones Dart y el documento está guardado.
Después de confirmar, VS Code aplica una única edición que quita ese widget
y manda el PNG a la papelera. Se guarda Dart para que la tarea persistente
de Flutter actualice la pantalla. Si falta la asociación o hay referencias
ambiguas, el inspector **no elimina nada**.

Las pantallas futuras pueden registrar sus elementos declarativamente
sin añadir controles de visibilidad particulares. Un bloque completo de
una lista de widgets, terminado en coma, se anota con estos comentarios:

```dart
// ai-apps:visual:start assets/scene/Stars.png
Image.asset('assets/scene/Stars.png'),
// ai-apps:visual:end assets/scene/Stars.png
```

La anotación no cambia el comportamiento de Flutter. Auth registra inicialmente
Background, Estrellas, Esferas y Robot de esta manera. Las imágenes que aún
no estén registradas se pueden mostrar, ocultar o sustituir, pero la
eliminación del código se rechazará para no romper la aplicación.

Los botones del ojo y el menú contextual se declaran en el manifiesto de
VS Code `scripts/vscode-android/package.json`. En instalaciones enlazadas
por junction se cargan con **Developer: Reload Window**. Si se instaló una
copia en vez del enlace, ejecutar `scripts/install-vscode-android.ps1` para
actualizar también el manifiesto instalado.

Pruebas: `node scripts/vscode-android/asset-actions.test.cjs`,
`node scripts/vscode-android/asset-inspector.test.cjs`,
`node scripts/vscode-android/test.cjs`.


## Repositorio y UI sincronizados

El explorador es una vista de la UI y los archivos originales, no una lista
paralela de imágenes. Cada PNG/JPG/WebP descubierto bajo el directorio de su
pantalla aparece automáticamente, sin registrarlo por nombre.

**Estado de la imagen** (detectado al examinar los literales de recursos en
`lib/**/*.dart`, ignorando comentarios de código):

- Ojo abierto: hay una referencia directa en Dart y la capa está visible.
- Ojo tachado: hay una referencia directa y se ha ocultado temporalmente.
- **⏳ Pendiente**: existe el archivo, pero no hay una referencia Dart directa.
  En lugar del ojo aparece el indicador de espera: todavía no existe una
  capa que se pueda ocultar. Pulsarlo explica cómo colocarla.

Los recursos con rutas generadas dinámicamente no se pueden verificar
estáticamente: se muestran como pendientes, no como colocados sin pruebas.
Los archivos pendientes se pueden renombrar, sustituir o eliminar sin
modificar Dart (confirmando antes de eliminarlos).

**Altas, bajas y cambios externos.** Los eventos de archivos del proyecto
actualizan el árbol sin intervención manual. Un segundo mecanismo revisa el
contenido de las carpetas y la firma de los archivos Dart cada cinco segundos
como respaldo para sincronizaciones Git y operaciones fuera de VS Code.
El mecanismo de revisión es compartido por todas las aplicaciones Flutter
registradas. No reinicia la tarea de desarrollo ni el emulador.

**Cambios de nombre.** «Cambiar nombre de imagen…» está en el menú contextual
del inspector y actualiza el PNG y las referencias Dart y de `pubspec.yaml`
en una misma edición. Si renombras desde el **Explorador de archivos de
VS Code**, se aplica el mismo mecanismo para imágenes y carpetas:
también se actualiza `assetDirectories` en `experiences.json` cuando
cambia el nombre de una carpeta. Esta operación está limitada a
**renombrar dentro de su directorio padre**, sin trasladar recursos a otra
pantalla. Se detiene ante documentos con cambios sin guardar o destinos
ocupados.

**Precaución:** si renombras una carpeta físicamente mediante PowerShell,
Windows Explorer o Git mientras VS Code no participa en la operación, el
sistema puede detectar la nueva ruta pero no siempre demostrar qué pantalla
era su propietaria. No reescribe Dart ni adivina la propiedad de esa carpeta:
para conservar los enlaces automáticamente, renómbrala en VS Code. Cambiar
externamente el nombre de una imagen dentro de su carpeta sí actualiza la
lista, pero la referencia Dart antigua queda sin resolver hasta corregirla.

Pruebas complementarias:
`node scripts/vscode-android/visual-source-index.test.cjs`,
`node scripts/vscode-android/visual-renames.test.cjs`.
