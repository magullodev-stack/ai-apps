# AGENTS.md — AI-APPS

## Fuentes de verdad

- `docs/MANIFIESTO ARQUITECTÓNICO.md`: arquitectura del proyecto.
- `docs/IA.md`: papel de la inteligencia artificial en AI-APPS.
- `docs/ÁRBOL DEL REPO.md`: organización del repositorio.
- `docs/HERRAMIENTAS.md`: catálogo de herramientas activas y archivadas.

Consulta la fuente correspondiente antes de intervenir en una responsabilidad del proyecto.

## Herramientas

Consulta `docs/HERRAMIENTAS.md` para localizar las herramientas disponibles, conocer su finalidad y acceder a sus instrucciones de uso.

Cuando se incorpore o modifique una herramienta, actualiza su entrada en el catálogo.

## Procedimiento de trabajo

1. Trabaja sobre el repositorio local abierto en VS Code. Comprueba la rama y el estado de Git antes de editar; conserva las modificaciones anteriores del usuario.
2. Identifica la responsabilidad afectada y consulta su documentación, implementación y pruebas.
3. Ejecuta el encargo en el componente correspondiente.
4. Verifica los cambios mediante las pruebas pertinentes y `git diff --check`.
5. Actualiza la documentación afectada.
6. **Contrato de entrega continua:** cuando el usuario encargue implementar o corregir algo, tras las comprobaciones disponibles haz commit y publica en `origin/dev` como parte del mismo trabajo, sin solicitar una autorización adicional para cada publicación. No confundas cambios preparados con cambios entregados: verifica el SHA remoto, y distingue publicación, sincronización local, aplicación en el emulador y prueba real. No publiques modificaciones ajenas, secretos ni archivos sensibles; ante bloqueos o pruebas pendientes, informa expresamente qué no se ha verificado. Cuando el usuario solo pida análisis, revisión o diseño sin implementar, no cambies el repositorio.
7. Comunica las verificaciones realizadas y el estado final de Git. Si se hizo un commit, comunica también su SHA completo.

## Entorno de desarrollo

- Repositorio local: `C:\Users\Miquelet\repos\ai-apps`.
- Terminal: PowerShell de Windows.
- Rama única del proyecto: `dev`.
- Remoto: `magullodev-stack/ai-apps`.

La aplicación móvil actual es `apps/muondia/`, un proyecto Flutter independiente. Consulta sus instrucciones operativas en `apps/muondia/README.md`. Su conservación es temporal; no desarrolles funcionalidades particulares de recorrido inicial como parte de la base común.

La tarea de Windows `AI-APPS Development` arranca al iniciar sesión y mantiene `emulator-5554`, Muondia mediante Flutter, el servicio Dart, Hot Reload automático y la sincronización continua de `dev`, independientemente de VS Code. `scripts/start-dev-session.ps1` conserva la propiedad de la sesión Flutter; VS Code solo visualiza el emulador mediante EmbeDroid. La configuración opcional F5 `Muondia` no detiene esta tarea: rechaza el arranque si está activa o si otro Flutter ocupa `emulator-5554`. Para depurar con F5, detén antes la tarea de forma explícita y verifica que no quedan procesos Flutter del dispositivo. El registro operativo está en `.ai-apps/dev-session.log`. Cuando la tarea se inicia y detecta un Flutter previo
en `emulator-5554`, `scripts/android/task-control.ps1 -Action Recover`
solo libera procesos que `flutter-ownership.ps1` verifica como propios de
este repositorio y después reconstruye una única sesión. Nunca detiene la
tarea que está arrancando ni interfiere con F5 u otro Flutter: una propiedad
ajena o ambigua bloquea el arranque. Este mecanismo recupera huérfanos en
el siguiente inicio, pero no sustituye la supervisión continua de la tarea.

**Invariante del entorno:** ningún cambio de herramientas, extensiones o depuradores puede sustituir el arranque persistente de Muondia, transferir a VS Code la propiedad de Flutter ni eliminar el Hot Reload de cambios sincronizados sin autorización expresa del usuario.

Muondia se identifica como `muondia` y `com.aiapps.muondia`. El test inicial de diez preguntas es onboarding obligatorio tras registrar la cuenta, previo a Home; no se ofrece desde Home como modalidad independiente. El estado de finalización se conserva por usuario.

AI-APPS Android incluye el Explorador de experiencias (`scripts/vscode-android/`). Cada aplicación declara las vistas previsualizables en `lib/app/development/experiences.json`; los assets no crean entradas. Muondia implementa sus previews en `apps/muondia/lib/app/development/`, con datos controlados y sin llamadas a IA. El panel comunica con la app mediante intents Android de depuración, sin reiniciar Flutter. Verificar mediante `node scripts/vscode-android/explorer.test.cjs`, `node scripts/vscode-android/test.cjs` y las pruebas Flutter.

El Explorador de experiencias está integrado directamente bajo cada aplicación activa dentro de `AI-APPS Android` (`aiAppsAndroid.sessions`), sin carpetas redundantes ni listados de laboratorios inactivos. Las categorías troncales se conservan incluso con una sola pantalla:
sirven para orientación y búsqueda con decenas de experiencias. Cada
aplicación puede declarar la acción debug segura `realFlowAction` para
regresar a su navegación real desde el mismo emulador, sin una nueva
sesión Flutter. Las vistas previas siguen simuladas; el modo real puede
ejecutar Firebase y el generador auténtico de onboarding, y persiste
tras Hot Reload. El explorador lee el estado debug del dispositivo mediante el archivo
privado `files/ai_apps_active_experience.txt` y `adb run-as` en su
sondeo habitual; la carpeta que contiene la pantalla activa muestra el
icono amarillo de carpeta abierta, y el nodo pantalla se destaca con ojo
amarillo. El estado se restaura tras recargar VS Code y refleja cambios de
experiencia desde el emulador. El modo real se identifica como tal; las
rutas internas de Flutter no están instrumentadas. No utilizar esta
observación para inferir identidades, contenido privado o navegación
no comunicada explícitamente por la aplicación. Los demás registros siguen administrables desde la paleta de comandos. En Muondia debug (sin `identityService` inyectado) arranca Auth de previsualización y el onboarding real no se ejecuta automáticamente; el modo release conserva el recorrido de usuarios. F7 también abre Auth simulado. Los tests de widget pueden activar/desactivar este arranque con `developmentPreviewOnStartup`.

El inspector visual compartido está en `shared/ui/lib/src/development/visual_asset_inspector.dart` y `scripts/vscode-android/asset-inspector.cjs`. Cada app integra una vez el `AiAppsVisualAssetScope` en `MaterialApp.builder`, conecta su controlador al canal `ai_apps/visual_inspector` y reenvía el intent Android de debug `DEV_ASSET_VISIBILITY`; nunca incorpora interruptores por pantalla. El inspector enumera los assets visuales de forma automática y solo modifica su visibilidad temporal; excluye referencias explícitas a `rootBundle`, plugins y recursos remotos. Probar `node scripts/vscode-android/asset-inspector.test.cjs` y pruebas Flutter de `shared/ui`.

El inspector visual presenta un ojo inline para la visibilidad reversible
y un menú nativo de VS Code para sustituir o eliminar imágenes. La propiedad
de una imagen sobre un elemento visual se declara rodeando el widget completo
de una lista con comentarios `// ai-apps:visual:start assets/...` y
`// ai-apps:visual:end assets/...`. Solo los bloques declarados, con
referencia única, pueden borrarse mediante un `WorkspaceEdit`; las demás
imágenes solo se ocultan o sustituyen. La lógica genérica se implementa en
`scripts/vscode-android/asset-actions.cjs`. No se realizan ediciones
heurísticas de Dart ni se eliminan recursos compartidos.

El inspector visual **no** crea «Capas e imágenes» ni árboles de assets
paralelos. Los recursos se muestran directamente bajo las experiencias del
explorador de UI usando `assetDirectories` en
`lib/app/development/experiences.json`; cada directorio pertenece a una
sola experiencia y se valida el no solapamiento. Los archivos se descubren
automáticamente dentro de esos directorios. Auth/Home siguen siendo
clicables para abrir preview y ahora también desplegables para sus imágenes.
Loading muestra sus estados e imágenes como hijos de la misma experiencia.
Las operaciones existentes (ojo, sustituir, eliminar de forma segura)
continúan aplicándose a los archivos originales.

El explorador sincroniza la UI con el repositorio de cada app: descubre
altas/bajas/cambios en directorios declarados y lee literales Dart para
mostrar un ojo solo en imágenes referenciadas, o `⏳ Pendiente` en recursos
sin referencia directa. El índice compartido se implementa en
`scripts/vscode-android/visual-source-index.cjs`; la extensión escucha
eventos de archivos y compara firmas de assets/Dart cada cinco segundos.
Los renombres hechos mediante el menú de imagen o el Explorador de archivos
de VS Code actualizan las referencias Dart, marcas de capa, pubspec y las
carpetas declaradas en el catálogo cuando proceda, mediante
`scripts/vscode-android/visual-renames.cjs`. No inferir ni refactorizar
automáticamente carpetas renombradas externamente sin un evento de renombre
identificable; evitar asociaciones ambiguas entre pantallas.

La eliminación del inspector utiliza un plan multiarchivo en
`scripts/vscode-android/asset-actions.cjs`: escanea Dart, pruebas y
documentación del proyecto, detecta referencias residuales y propiedades
de widget en fragmentos registrados. Bloques de una misma capa pueden
declararse repetidamente en lib/test con marcas de propiedad; los editados
se aplican conjuntamente. Ante referencias no registradas o documentos
que describan la imagen, se cancela el borrado antes de tocar archivos.
Los recursos pendientes también se comprueban antes de enviarlos a papelera.
No debe reaparecer en la UI Flutter ningún panel local «Capas»; el gestor
de imágenes es exclusivamente el explorador de AI-APPS Android.

El watcher persistente de Flutter **no abandona** una actualización tras
un Hot Reload fallido: `scripts/flutter-dev-runner.dart` serializa las
peticiones y prueba un único Hot Restart de la misma sesión. Un Hot Restart
fallido se registra sin reintentos en bucle; un canal machine bloqueado
durante 120 segundos relanza exclusivamente el Flutter hijo ya controlado
por el runner y delega su reconstrucción en `run.ps1`, sin F5 ni reiniciar
Android. No registrar salida arbitraria/credenciales en
`.ai-apps/dev-session.log`. Prueba:
`dart scripts/flutter-dev-runner-machine-test.dart`.
