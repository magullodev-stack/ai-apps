# AGENTS.md

## Propósito

Este repositorio contiene Quiz10.

Los agentes que trabajen en él deben actuar como ejecutores de las especificaciones y decisiones mantenidas en el propio repositorio.

El estado real del repositorio es la fuente de verdad.

No asumas que una descripción previa coincide con el contenido actual de los archivos. Inspecciona siempre el estado real antes de modificar elementos existentes.

---

## Principio de trabajo

El flujo normal de cualquier tarea es:

1. inspeccionar;
2. comprender;
3. modificar únicamente el alcance solicitado;
4. verificar;
5. informar del estado resultante.

No amplíes autónomamente el alcance de una tarea.

No introduzcas arquitectura, dependencias, herramientas, versiones, servicios o abstracciones que no estén requeridos por la especificación vigente.

Cuando falte una decisión necesaria para continuar correctamente, señala el bloqueo en lugar de inventar la decisión.

---

## Arquitectura

Quiz10 utiliza una separación conceptual A–B–C.

### A — `core/`

Contiene infraestructura, contratos y servicios técnicos.

A hace posible el producto, pero no contiene reglas específicas de Quiz10.

### B — `systems/`

Contiene la lógica del producto.

Las reglas de Quiz10 pertenecen a B.

B no depende de componentes visuales concretos ni de detalles técnicos de proveedores externos.

### C — `ui/`

Contiene la materialización visible e interactiva del producto.

C representa estados y comunica intervenciones.

C no gobierna las reglas del juego ni modifica directamente el estado del dominio.

### Composición — `apps/`

Los ejecutables ensamblan A, B y C.

No contienen una segunda implementación de las reglas del producto.

---

## Fronteras arquitectónicas

Respeta estas reglas:

- `core/` no conoce reglas concretas de Quiz10.
- `systems/` no depende de Jetpack Compose ni de otra UI concreta.
- `systems/` no accede directamente a SDKs o implementaciones concretas de IA, persistencia, autenticación, red o facturación.
- `ui/` no contiene reglas de partida.
- `ui/` no modifica directamente el estado del dominio.
- `apps/` ensambla y delega.
- Los temas introducidos por el usuario son datos de ejecución, no nuevos sistemas arquitectónicos.
- Las integraciones técnicas deben quedar desacopladas de las reglas de Quiz10.
- La representación visual no debe convertirse en fuente de verdad del estado del juego.

No crees dependencias que contradigan estas fronteras.

---

## Documentación normativa

Antes de realizar cambios arquitectónicos o tecnológicos, consulta estos documentos cuando existan:

- `docs/ARCHITECTURE.md`
- `docs/TECH_STACK.md`
- `docs/WORKFLOW.md`
- `docs/adr/`

Si una instrucción contradice la documentación normativa o el estado real del repositorio, señala la discrepancia antes de modificar.

---

## Modificación de archivos existentes

Antes de modificar un archivo existente:

1. inspecciona su contenido actual;
2. inspecciona las dependencias relevantes;
3. identifica las reglas arquitectónicas y tecnológicas aplicables;
4. realiza la modificación mínima necesaria;
5. verifica el resultado.

No utilices números de línea obtenidos de estados anteriores del archivo.

No reemplaces un archivo completo cuando una modificación localizada sea suficiente, salvo que la tarea lo requiera expresamente.

---

## Creación de archivos

Antes de crear un archivo:

1. confirma que su responsabilidad no pertenece ya a otro archivo o módulo;
2. confirma su ubicación correcta dentro de la arquitectura;
3. aplica las convenciones existentes del repositorio;
4. evita crear abstracciones anticipadas sin necesidad demostrada.

---

## Dependencias y versiones

No selecciones arbitrariamente versiones de:

- JDK;
- Kotlin;
- Gradle;
- Android Gradle Plugin;
- Android SDK;
- Jetpack Compose;
- Ktor;
- PostgreSQL;
- librerías;
- herramientas de análisis;
- imágenes de contenedor;
- servicios externos.

Utiliza las versiones fijadas por el repositorio.

Si una versión necesaria todavía no está especificada, señala el bloqueo antes de introducirla.

---

## Entorno de desarrollo

La estación base ya está instalada, configurada y verificada.

El entorno habitual es:

Windows 11 → VS Code → WSL 2 → Ubuntu 24.04 → repositorio.

Cuando el proyecto utiliza aislamiento:

Windows 11 → VS Code → WSL 2 → Ubuntu 24.04 → Docker Desktop → Dev Container.

Los repositorios se encuentran en:

`~/repos/<repo>`

No reinstales ni reconfigures la estación base salvo que exista un fallo concreto que lo justifique.

No apliques confianza global a `~/repos`.

El ámbito normal de trabajo comienza en el repositorio abierto y continúa en su entorno de proyecto y su código.

---

## Seguridad

No almacenes secretos, tokens, credenciales o claves privadas en archivos versionados.

No introduzcas claves de proveedores de IA dentro de aplicaciones cliente.

No muestres secretos en logs, pruebas o documentación.

---

## Git

No ejecutes:

- `commit`;
- `push`;
- `merge`;
- `rebase`;
- creación o eliminación de ramas;
- operaciones destructivas de Git;

salvo instrucción explícita.

No descartes cambios existentes del usuario.

No sobrescribas trabajo no relacionado con la tarea actual.

---

## Verificación

Después de crear o modificar archivos:

1. ejecuta las comprobaciones aplicables;
2. corrige los fallos introducidos por el cambio;
3. distingue los fallos preexistentes de los provocados por la tarea;
4. informa de las comprobaciones realizadas y sus resultados.

Un archivo solo puede considerarse terminado cuando esté:

- implementado;
- integrado;
- verificado.

No declares como verificado aquello que no haya sido comprobado.

---

## Cambios fuera de alcance

Si para completar una tarea parece necesario modificar archivos fuera del alcance solicitado:

1. inspecciona la dependencia;
2. explica por qué sería necesario;
3. no amplíes silenciosamente el alcance.

---

## Resultado de una tarea

Al terminar una tarea informa de forma concreta:

- archivos creados;
- archivos modificados;
- verificaciones ejecutadas;
- resultado de las verificaciones;
- bloqueos existentes;
- discrepancias detectadas.

No presentes como completado aquello que continúe pendiente de integración o verificación.
