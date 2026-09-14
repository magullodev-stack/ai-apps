# AGENTS.md

## Fuente de verdad

El estado actual del repositorio es la fuente de verdad.

Antes de modificar algo existente, inspecciona el archivo y las dependencias relevantes.

Haz únicamente lo solicitado. No amplíes el alcance ni introduzcas arquitectura, dependencias, servicios, herramientas o abstracciones no requeridas.

Si falta una decisión necesaria, detente e informa del bloqueo. No la inventes.

## Arquitectura

Quiz10 se organiza así:

- `core/` — A: infraestructura, contratos y servicios técnicos.
- `systems/` — B: lógica y reglas del producto.
- `ui/` — C: representación e interacción.
- `apps/` — composición ejecutable.

Reglas de frontera:

- `core/` no contiene reglas específicas de Quiz10.
- `systems/` no depende de UI concreta ni de implementaciones externas concretas.
- `ui/` no gobierna el dominio ni es fuente de verdad del estado.
- `apps/` ensambla y delega.

Consulta `docs/ARCHITECTURE.md` solo cuando la tarea implique una decisión arquitectónica.

## Tecnología

Usa las versiones, dependencias y herramientas ya fijadas por el repositorio.

No selecciones nuevas versiones o tecnologías arbitrariamente.

Si una tarea necesita una decisión tecnológica todavía no fijada, informa del bloqueo.

## Entorno

La estación base ya está configurada.

No reinstales ni reconfigures WSL, Docker Desktop, Git, VS Code ni otras herramientas base salvo que exista un fallo concreto.

Cuando el proyecto disponga de Dev Container, ejecuta dentro de él las tareas propias del proyecto.

## Seguridad

No almacenes secretos, tokens, credenciales o claves privadas en archivos versionados.

Las claves de proveedores externos no deben introducirse en aplicaciones cliente.

## Git

No hagas `commit`, `push`, `merge`, `rebase`, cambios de rama ni operaciones destructivas salvo instrucción explícita.

No descartes ni sobrescribas cambios ajenos a la tarea actual.

## Verificación

Después de modificar:

1. ejecuta las comprobaciones aplicables;
2. corrige los fallos introducidos por el cambio;
3. informa del resultado real.

No declares terminado algo que no haya sido implementado, integrado y verificado.

## Resultado

Al finalizar informa brevemente de:

- archivos creados, modificados o eliminados;
- verificaciones ejecutadas;
- bloqueos o discrepancias reales.