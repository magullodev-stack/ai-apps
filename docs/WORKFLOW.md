# Flujo de trabajo de Quiz10

## Principio

El repositorio real es la fuente de verdad.

El trabajo avanza mediante cambios pequeños, concretos y verificables.

## Ciclo

Cada tarea sigue este flujo:

1. inspeccionar el estado actual;
2. comprender la responsabilidad afectada;
3. implementar únicamente el alcance solicitado;
4. ejecutar las verificaciones aplicables;
5. corregir los fallos introducidos;
6. informar del resultado.

Si falta una decisión necesaria, se detiene la parte afectada y se señala el bloqueo.

## Alcance

No se amplía una tarea silenciosamente.

No se añaden refactorizaciones, dependencias, abstracciones o archivos no necesarios para completar el objetivo actual.

Los cambios ajenos a la tarea se conservan intactos.

## Archivos

Antes de modificar un archivo existente se inspeccionan su contenido y dependencias relevantes.

Antes de crear uno nuevo se comprueba:

- que su responsabilidad no exista ya;
- que pertenece a la ubicación correcta;
- que responde a una necesidad real.

## Verificación

Una pieza se considera terminada cuando está:

- implementada;
- integrada;
- verificada.

Según el cambio, la verificación puede incluir compilación, tests, análisis estático, validación de configuración o inspección del estado de Git.

No se declara como verificado algo que no se haya comprobado.

## Git

`git status`, `git diff` y otras operaciones de inspección pueden utilizarse libremente.

`commit`, `push`, `merge`, `rebase`, cambios de rama y operaciones destructivas requieren instrucción explícita.

## Codex

Codex ejecuta sobre el repositorio real.

Su función es:

- inspeccionar;
- implementar;
- ejecutar herramientas;
- verificar;
- informar.

Las decisiones de producto y arquitectura no se inventan durante la ejecución.

## Documentación

Consulta únicamente la documentación necesaria para la tarea actual.

- `AGENTS.md` contiene las reglas operativas permanentes.
- `docs/ARCHITECTURE.md` contiene las decisiones arquitectónicas.
- Este archivo define el flujo de trabajo.

No se duplica una misma decisión entre documentos.