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

La tarea de Windows `AI-APPS Development` prepara `emulator-5554` y mantiene Muondia, el servicio Dart y Hot Reload automático desde el inicio de sesión, independientemente de VS Code. Se instala con `scripts/install-dev-session.ps1` y ejecuta `scripts/start-dev-session.ps1`. VS Code únicamente visualiza el Android existente mediante EmbeDroid; cerrarlo no termina el entorno. Para iniciar o reutilizar la sesión, usa `Start-ScheduledTask -TaskName 'AI-APPS Development'`; no ejecutes otro Flutter sobre el mismo dispositivo. Para pruebas manuales, detén temporalmente la tarea, confirma que no quedan ejecutores Flutter y restáurala después. El resumen compartido de los diagnósticos está en `diagnostics/current.json`, generado mediante `scripts/diagnostics/collect.cjs` y publicado por `scripts/auto-sync-dev.ps1`. Recoge identificadores de problemas Gradle y eventos tipificados de la estación, no logs completos ni secretos. Los logs originales permanecen locales en `.ai-apps/`; una marca de comprobación antigua no garantiza el estado actual de Windows. Consulta `scripts/diagnostics/README.md`. Las llamadas reales a modelos y las pruebas que puedan interrumpir sesiones activas se coordinan con el usuario.

Muondia se identifica como `muondia` y `com.aiapps.muondia`. El test inicial de diez preguntas es onboarding obligatorio tras registrar la cuenta, previo a Home; no se ofrece desde Home como modalidad independiente. El estado de finalización se conserva por usuario.
