# AGENTS.md — AI-APPS

## Fuentes de verdad

- `docs/MANIFIESTO ARQUITECTÓNICO.md`: arquitectura del proyecto.
- `docs/IA.md`: papel de la inteligencia artificial en AI-APPS.
- `docs/ÁRBOL DEL REPO.md`: organización del repositorio.
- `docs/HERRAMIENTAS.md`: catálogo de herramientas y capacidades disponibles.

Consulta la fuente correspondiente antes de intervenir en una responsabilidad del proyecto.

## Herramientas

Consulta `docs/HERRAMIENTAS.md` para localizar las herramientas disponibles, conocer su finalidad y acceder a sus instrucciones de uso.

Cuando se incorpore o modifique una herramienta, actualiza su entrada en el catálogo.

## Procedimiento de trabajo

1. Comprueba la rama, el estado local y `origin/dev`.
2. Identifica la responsabilidad afectada y consulta su documentación, implementación y pruebas.
3. Ejecuta el encargo en el componente correspondiente.
4. Verifica los cambios mediante las pruebas pertinentes y `git diff --check`.
5. Actualiza la documentación afectada.
6. Publica en `origin/dev` cuando el encargo incluya publicación.
7. Comunica el SHA completo, las verificaciones realizadas y el estado final de Git.

## Entorno de desarrollo

- Repositorio: `/workspaces/ai-apps`.
- Rama de desarrollo: `dev`.
- Rama estable: `main`.
- Remoto: `magullodev-stack/ai-apps`.

Las llamadas reales a modelos y las pruebas que puedan interrumpir sesiones activas se coordinan con el usuario. La publicación en `main` requiere autorización expresa.