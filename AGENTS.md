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

La tarea de Windows `AI-APPS Development` prepara `emulator-5554`, el servicio Dart y la sincronización automática de `dev`; **ya no inicia Flutter**. Muondia se lanza con **F5** desde la configuración `Muondia` en VS Code, mediante la extensión oficial Dart/Flutter y Hot Reload al guardar. La tarea previa de F5 termina el antiguo runner persistente si sigue activo y prepara la conexión local con el servicio de IA. No ejecutes dos sesiones Flutter simultáneas en `emulator-5554`. El registro operativo está en `.ai-apps/dev-session.log`.

Muondia se identifica como `muondia` y `com.aiapps.muondia`. El test inicial de diez preguntas es onboarding obligatorio tras registrar la cuenta, previo a Home; no se ofrece desde Home como modalidad independiente. El estado de finalización se conserva por usuario.
