# Guía de entrada para agentes de desarrollo

AI-APPS construye aplicaciones centradas en actividades humanas. Lee el [manifiesto arquitectónico](docs/MANIFIESTO%20ARQUITECTÓNICO.md) antes de cambiar límites entre módulos; el [árbol del repositorio](docs/ÁRBOL%20DEL%20REPO.md) muestra también planes futuros, que no equivalen a código existente.

`core/` ofrece capacidades técnicas compartidas; `systems/` define el significado, estado y reglas de cada actividad; `ui/` presenta la experiencia; `apps/` conecta todo en ejecutables y configura efectos externos. `systems/` puede depender de `core/`, pero `core/` no depende de `systems/`; las reglas de dominio no dependen de una UI ni de proveedores concretos. Amplía una responsabilidad existente antes de duplicarla.

Los **agentes de desarrollo** leen y modifican este repositorio. Los **modelos de IA usados por las aplicaciones** son dependencias en tiempo de ejecución: generan o revisan contenido mediante `core/ai/` y las decisiones de cada sistema. Sus nombres o perfiles no designan agentes responsables del código.

## Índice actual

| Ubicación | Responsabilidad | Documentación |
| --- | --- | --- |
| `systems/games/quiz10/` | Reglas de Quiz10: cobertura, preguntas, preparación, sesión, interacción y progreso. | [Manifiesto](docs/MANIFIESTO%20ARQUITECTÓNICO.md), [árbol](docs/ÁRBOL%20DEL%20REPO.md) |
| `ui/quiz10-web/` | Renderizado de la interfaz web de Quiz10. | [Árbol](docs/ÁRBOL%20DEL%20REPO.md) |
| `apps/quiz10/` | Entrada ejecutable de Quiz10. | [Árbol](docs/ÁRBOL%20DEL%20REPO.md) |
| `apps/quiz10-web/` | Servidor web, composición de Quiz10 y comando de consulta de consumo. | [Monitor](docs/AI_USAGE_MONITOR.md) |
| `core/contracts/` | Contratos técnicos de resultado (`Outcome`). | [Árbol](docs/ÁRBOL%20DEL%20REPO.md) |
| `core/config/` | Configuración de entorno y modelos. | [Árbol](docs/ÁRBOL%20DEL%20REPO.md) |
| `core/network/` | Transporte HTTP. | [Árbol](docs/ÁRBOL%20DEL%20REPO.md) |
| `core/ai/` | Generación estructurada, cliente de Responses, monitor compartido de consumo y auditorías por fila. | [Monitor](docs/AI_USAGE_MONITOR.md) |

Antes de intervenir, identifica la actividad o capacidad afectada, busca su implementación y pruebas con `rg`, y comprueba sus dependencias en `settings.gradle.kts` y los `build.gradle.kts`. Usa este índice para llegar al módulo y el código para confirmar la responsabilidad exacta. Cuando aparezca un módulo o una capacidad compartida real, actualiza aquí su ubicación, función y enlace documental; distingue el código presente de los planes del árbol.

## Trabajo habitual en `dev`

Comprueba rama y estado de Git, realiza el cambio en el módulo dueño de la responsabilidad y ajusta la documentación pertinente. Ejecuta las pruebas Gradle de los módulos afectados (o `./gradlew test` para cambios transversales), revisa `git diff` y `git diff --check`, crea un commit descriptivo y publica con `git push origin dev`. Comunica el SHA, los archivos modificados, las verificaciones y el estado final de Git.
