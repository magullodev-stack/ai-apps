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

La prueba técnica móvil actual es `apps/quizai/`, un proyecto Flutter independiente. Consulta sus instrucciones operativas en `apps/quizai/README.md`. Su conservación es temporal; no desarrolles funcionalidades particulares de Quiz10 como parte de la base común.

El emulador Android compartido se prepara automáticamente al abrir AI-APPS en VS Code; el juego seleccionado se ejecuta mediante su propio lanzador. Las llamadas reales a modelos y las pruebas que puedan interrumpir sesiones activas se coordinan con el usuario.