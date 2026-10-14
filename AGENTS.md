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
6. Haz commit o publica en `origin/dev` únicamente cuando el usuario lo solicite expresamente.
7. Comunica las verificaciones realizadas y el estado final de Git. Si se hizo un commit, comunica también su SHA completo.

## Entorno de desarrollo

- Repositorio local: `C:\Users\Miquelet\repos\ai-apps`.
- Terminal: PowerShell de Windows.
- Rama única del proyecto: `dev`.
- Remoto: `magullodev-stack/ai-apps`.

La aplicación móvil actual es `apps/muondia/`, un proyecto Flutter independiente. Consulta sus instrucciones operativas en `apps/muondia/README.md`. Su conservación es temporal; no desarrolles funcionalidades particulares de recorrido inicial como parte de la base común.

La tarea de Windows `AI-APPS Development` arranca al iniciar sesión y mantiene `emulator-5554`, Muondia mediante Flutter, el servicio Dart, Hot Reload automático y la sincronización continua de `dev`, independientemente de VS Code. `scripts/start-dev-session.ps1` conserva la propiedad de la sesión Flutter; VS Code solo visualiza el emulador mediante EmbeDroid. La configuración opcional F5 `Muondia` no detiene esta tarea: rechaza el arranque si está activa o si otro Flutter ocupa `emulator-5554`. Para depurar con F5, detén antes la tarea de forma explícita y verifica que no quedan procesos Flutter del dispositivo. El registro operativo está en `.ai-apps/dev-session.log`.

**Invariante del entorno:** ningún cambio de herramientas, extensiones o depuradores puede sustituir el arranque persistente de Muondia, transferir a VS Code la propiedad de Flutter ni eliminar el Hot Reload de cambios sincronizados sin autorización expresa del usuario.

Muondia se identifica como `muondia` y `com.aiapps.muondia`. El test inicial de diez preguntas es onboarding obligatorio tras registrar la cuenta, previo a Home; no se ofrece desde Home como modalidad independiente. El estado de finalización se conserva por usuario.

AI-APPS Android incluye el Explorador de experiencias (`scripts/vscode-android/`). Cada aplicación declara las vistas previsualizables en `lib/app/development/experiences.json`; los assets no crean entradas. Muondia implementa sus previews en `apps/muondia/lib/app/development/`, con datos controlados y sin llamadas a IA. El panel comunica con la app mediante intents Android de depuración, sin reiniciar Flutter. Verificar mediante `node scripts/vscode-android/explorer.test.cjs`, `node scripts/vscode-android/test.cjs` y las pruebas Flutter.

El Explorador de experiencias está integrado directamente bajo cada aplicación activa dentro de `AI-APPS Android` (`aiAppsAndroid.sessions`), sin carpetas redundantes ni listados de laboratorios inactivos. Los grupos con una sola experiencia se aplanan. Los demás registros siguen administrables desde la paleta de comandos. En Muondia debug (sin `identityService` inyectado) arranca Auth de previsualización y el onboarding real no se ejecuta automáticamente; el modo release conserva el recorrido de usuarios. F7 también abre Auth simulado. Los tests de widget pueden activar/desactivar este arranque con `developmentPreviewOnStartup`.
