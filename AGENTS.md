# AGENTS.md

## Fuente de verdad

El estado actual del repositorio es la fuente de verdad.

Antes de modificar algo existente, inspecciona el archivo y las dependencias relevantes.

Haz únicamente lo solicitado. No amplíes el alcance ni introduzcas arquitectura, dependencias, servicios, herramientas o abstracciones no requeridas.

Si para completar la tarea falta una decisión de producto, un contrato público o una decisión arquitectónica que afecte al comportamiento observable y no pueda deducirse de la tarea ni del repositorio, detente e informa del bloqueo. No la inventes.

Las decisiones internas de implementación que respeten el alcance, los contratos y la arquitectura existente corresponden a Codex o Copilot.

## Arquitectura

Documentación vigente:

- `docs/MANIFIESTO ARQUITECTÓNICO.md`
- `docs/ÁRBOL DEL REPO.md`

`ai-apps` se organiza así:

- `core/` — capacidades técnicas e infraestructura compartida.
- `systems/` — lógica y reglas de los sistemas.
- `ui/` — presentación e interacción.
- `apps/` — composición ejecutable.

Reglas de frontera:

- `core/` permanece neutral respecto a sistemas y aplicaciones.
- `systems/` contiene las reglas de producto y puede utilizar `core/`.
- `ui/` no gobierna el dominio ni es fuente de verdad del estado.
- `apps/` ensambla y delega.
- Los sistemas pueden coexistir sin conocerse entre sí.
- Las abstracciones compartidas aparecen por reutilización real, no por anticipación.

### Estado y efectos inteligentes

- El estado estructurado del sistema es la fuente de verdad operacional.
- La IA nunca modifica el estado directamente.
- Las acciones del usuario se procesan como eventos del sistema.
- Cuando una transición necesita interpretación o generación no determinista, el sistema puede solicitar un efecto inteligente tipado.
- La salida de un efecto inteligente es una propuesta estructurada, no estado.
- `systems/` valida esa propuesta y decide si la convierte en un evento o en nuevo estado.
- Si una transición puede resolverse de forma determinista, no introduzcas IA innecesariamente.
- Los fallos de un efecto inteligente no deben dejar el sistema en un estado parcialmente aplicado o incoherente.
- El dominio define la intención, los contratos y las validaciones; la infraestructura ejecuta la capacidad técnica y `apps/` selecciona y compone las implementaciones concretas.

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