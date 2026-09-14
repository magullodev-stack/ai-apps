# Flujo de trabajo de Quiz10

## Propósito

Este documento define el procedimiento de trabajo utilizado para construir y mantener Quiz10.

El objetivo es que cada cambio en el repositorio sea:

- deliberado;
- localizado;
- inspeccionado;
- coherente con la arquitectura;
- verificable;
- trazable.

La implementación no debe adelantarse al diseño.

El estado real del repositorio es siempre la fuente de verdad sobre lo que existe.

---

# 1. Ciclo general de trabajo

El flujo normal es:

**Diseño → Especificación → Inspección → Implementación → Verificación → Estado**

La arquitectura, las responsabilidades y las reglas se deciden antes de materializarlas en código.

Un agente ejecutor no debe completar silenciosamente decisiones arquitectónicas o tecnológicas que todavía no hayan sido fijadas.

Cuando falte una decisión necesaria para continuar correctamente, debe señalarse como bloqueo.

---

# 2. Unidad de cambio

Quiz10 se construye mediante unidades de cambio pequeñas y verificables.

Una tarea debe intentar resolver una responsabilidad concreta.

Se evita utilizar instrucciones amplias como:

> “Implementa todo el sistema Quiz10.”

Se prefieren secuencias como:

**Contrato → Modelo → Regla → Orquestación → Adaptador → Interfaz**

Cada unidad debe quedar integrada y verificada antes de avanzar cuando exista una dependencia directa entre ellas.

---

# 3. Creación de archivos

Cuando una tarea requiera crear un archivo nuevo, la especificación debe utilizar esta estructura:

## Instrucción

**Crea el `<archivo>`: descripción breve de su responsabilidad dentro del producto.**

## Destino

**Destino🗂️: `ruta/relativa/al/repositorio/archivo.ext`**

## Contenido

Debe proporcionarse el contenido completo del archivo cuando la especificación determine exactamente su implementación.

Antes de crearlo, el agente debe:

1. inspeccionar el contexto relevante;
2. confirmar que la responsabilidad no está ya implementada;
3. comprobar que la ubicación corresponde a la arquitectura;
4. aplicar las convenciones vigentes del repositorio;
5. comprobar las dependencias necesarias.

No deben introducirse archivos auxiliares no solicitados sin justificar previamente su necesidad.

---

# 4. Modificación de archivos existentes

Antes de modificar un archivo existente, el agente debe:

1. inspeccionar su contenido actual;
2. inspeccionar las dependencias relevantes;
3. consultar las reglas arquitectónicas aplicables;
4. comprobar si la especificación sigue siendo compatible con el estado real;
5. realizar el cambio mínimo necesario.

Las instrucciones de modificación deben indicar de forma precisa la operación.

Ejemplos:

- sustituir un bloque concreto;
- modificar una función;
- modificar una clase;
- modificar una interfaz;
- añadir una sección;
- eliminar un bloque;
- actualizar una configuración concreta.

No debe reemplazarse un archivo completo cuando una modificación localizada sea suficiente, salvo que la tarea lo requiera expresamente.

Los números de línea solo se utilizan cuando corresponden al estado real previamente inspeccionado.

---

# 5. Sincronización con el repositorio

Antes de ejecutar una modificación, debe compararse la especificación con el estado real del repositorio.

Si existe una discrepancia:

1. se identifica;
2. se explica;
3. no se oculta mediante una modificación improvisada;
4. se detiene la parte afectada si la discrepancia requiere una decisión.

El repositorio prevalece sobre suposiciones derivadas de conversaciones anteriores.

La documentación normativa debe mantenerse sincronizada con las decisiones vigentes.

---

# 6. Alcance

Cada tarea debe respetar su alcance explícito.

El agente no debe ampliar silenciosamente una tarea porque detecte oportunidades adicionales de refactorización o mejora.

Si una dependencia obliga aparentemente a modificar elementos fuera del alcance:

1. se inspecciona;
2. se explica la necesidad;
3. se solicita o espera una decisión antes de ampliar el cambio cuando corresponda.

Los cambios no relacionados deben permanecer intactos.

---

# 7. Arquitectura

Toda implementación debe respetar `docs/ARCHITECTURE.md`.

La clasificación conceptual es:

- A → `core/`
- B → `systems/`
- C → `ui/`
- composición → `apps/`

Antes de crear una nueva pieza debe poder responderse:

- qué responsabilidad tiene;
- qué capa posee autoridad sobre ella;
- de qué depende;
- quién puede depender de ella;
- por qué no pertenece ya a una pieza existente.

No se crean abstracciones únicamente por una posible utilidad futura.

---

# 8. Tecnología

Las decisiones tecnológicas vigentes se documentan en:

`docs/TECH_STACK.md`

No deben seleccionarse arbitrariamente versiones, librerías, herramientas o proveedores que todavía no hayan sido fijados.

Cuando una tarea dependa de una decisión tecnológica pendiente, debe declararse el bloqueo.

La implementación debe utilizar las herramientas controladas por el repositorio siempre que sea posible.

---

# 9. Verificación

Después de crear o modificar archivos deben ejecutarse las comprobaciones aplicables.

Según la naturaleza del cambio pueden incluir:

- compilación;
- tests unitarios;
- tests de integración;
- tests de arquitectura;
- lint;
- análisis estático;
- validación de formato;
- validación de configuración;
- comprobaciones específicas de plataforma;
- inspección directa del archivo resultante;
- estado de Git.

El agente debe corregir los fallos introducidos por su propio cambio dentro del alcance autorizado.

Debe distinguir:

- fallos provocados por la tarea;
- fallos preexistentes;
- bloqueos de entorno;
- verificaciones que todavía no son aplicables.

No debe afirmarse que algo está verificado si la comprobación correspondiente no se ha ejecutado.

---

# 10. Estados

Cada archivo o pieza seguida durante la construcción utiliza uno de estos estados:

- `⏳` → pendiente;
- `⚠️` → en curso;
- `✅` → implementado, integrado y verificado.

Un archivo solo puede pasar a `✅` cuando:

1. existe en el estado esperado;
2. está correctamente integrado;
3. se han realizado las verificaciones aplicables;
4. no mantiene bloqueos pendientes;
5. no mantiene alertas abiertas.

---

# 11. Checklist vivo

Durante la construcción se mantiene una tabla conceptual con estas columnas:

| Columna | Significado |
|---|---|
| ID | Ruta exacta relativa a la raíz del repositorio |
| Descripción | Resumen concreto de lo implementado o modificado |
| API pública | Elementos públicos expuestos |
| Reglas | Reglas arquitectónicas, de codificación o tecnología aplicadas |
| Estado | `⏳`, `⚠️` o `✅` |
| Desbloqueo | Condición pendiente necesaria para continuar o finalizar |
| Alerta | Problema detectado que requiere revisión |

Cuando un bloqueo queda satisfecho, su campo debe quedar vacío.

Cuando una alerta queda resuelta y verificada, su campo debe quedar vacío.

---

# 12. Árbol parcial del repositorio

Durante la construcción se mantiene una representación parcial y viva del repositorio.

Solo se despliegan con detalle las ramas relevantes que estén actualmente en construcción.

Una rama completamente terminada puede resumirse como:

`carpeta/ ✅`

El objetivo no es reproducir continuamente todo el repositorio, sino conservar visibilidad sobre el área activa de trabajo.

---

# 13. Carpetas terminadas

Una carpeta, bloque o sistema solo se considera completamente terminado cuando:

- todos sus archivos tienen estado `✅`;
- todos los campos de desbloqueo están vacíos;
- todos los campos de alerta están vacíos;
- las verificaciones aplicables han finalizado correctamente.

La existencia física de todos los archivos no implica por sí sola que el bloque esté terminado.

---

# 14. Git

Git forma parte del mecanismo de control del desarrollo.

Sin embargo, los agentes no deben ejecutar de forma autónoma:

- commits;
- push;
- merge;
- rebase;
- creación o eliminación de ramas;
- operaciones destructivas;

salvo instrucción explícita.

No deben descartarse cambios del usuario.

No deben sobrescribirse cambios no relacionados con la tarea actual.

`git status` puede utilizarse como herramienta de inspección y verificación.

---

# 15. Commits

Los commits deben representar estados coherentes y verificables del repositorio.

Conceptualmente:

**Estado₀ → cambio verificado → Estado₁**

No se realiza un commit únicamente porque se haya creado un archivo.

El commit debe corresponder a una unidad de trabajo suficientemente coherente y comprobada.

La creación del commit requiere una instrucción explícita.

---

# 16. Uso de Codex

Codex actúa sobre el repositorio real.

Su responsabilidad principal es:

- inspeccionar;
- implementar especificaciones;
- ejecutar herramientas;
- verificar resultados;
- informar de discrepancias.

Codex no sustituye la definición arquitectónica del producto.

El flujo deseado es:

**Diseño → instrucción precisa → Codex → repositorio → verificación**

Codex dispone de libertad operativa dentro del alcance autorizado, pero no de libertad para redefinir silenciosamente la arquitectura.

---

# 17. Documentación normativa

Los documentos principales del repositorio son:

- `AGENTS.md`
- `docs/ARCHITECTURE.md`
- `docs/TECH_STACK.md`
- `docs/WORKFLOW.md`
- `docs/adr/` cuando existan ADRs

Antes de tareas arquitectónicas o tecnológicas relevantes, el agente debe consultar la documentación aplicable.

La documentación debe describir el estado y las decisiones vigentes, no aspiraciones abandonadas.

---

# 18. ADR

Las decisiones arquitectónicas significativas pueden registrarse mediante Architecture Decision Records.

Una ADR debe utilizarse cuando resulte valioso conservar:

- el problema;
- las alternativas consideradas;
- la decisión tomada;
- las razones;
- las consecuencias.

No toda decisión necesita una ADR.

Las decisiones triviales o puramente locales pueden permanecer documentadas donde corresponda.

---

# 19. Seguridad

Nunca deben versionarse:

- secretos;
- tokens;
- contraseñas;
- claves privadas;
- credenciales de servicios;
- claves de proveedores de IA.

Las aplicaciones cliente no deben contener secretos que permitan utilizar directamente servicios protegidos.

Los secretos tampoco deben aparecer en:

- logs;
- fixtures;
- ejemplos;
- tests;
- documentación;
- capturas de salida.

---

# 20. Entorno de desarrollo

La estación base ya está instalada y verificada.

El entorno habitual es:

**Windows 11 → VS Code → WSL 2 → Ubuntu 24.04 → repositorio**

Cuando el proyecto utiliza aislamiento:

**Windows 11 → VS Code → WSL 2 → Ubuntu 24.04 → Docker Desktop → Dev Container**

Los repositorios se encuentran en:

`~/repos/<repo>`

No se reinstala ni reconfigura la estación base salvo que exista un fallo concreto que lo justifique.

La configuración específica del proyecto pertenece al repositorio.

---

# 21. Criterio de finalización de una tarea

Una tarea finaliza correctamente cuando:

1. el alcance solicitado se ha implementado;
2. no se han realizado cambios colaterales injustificados;
3. las comprobaciones aplicables han terminado;
4. los fallos introducidos por el cambio se han corregido;
5. los bloqueos restantes están identificados;
6. el resultado ha sido comunicado de forma precisa.

El informe final debe indicar:

- archivos creados;
- archivos modificados;
- verificaciones ejecutadas;
- resultados;
- bloqueos;
- discrepancias.

---

# 22. Siguiente paso

Después de cada unidad de trabajo debe elegirse una de estas dos acciones:

1. continuar con el archivo o bloque actual si todavía no está terminado;
2. pasar al siguiente archivo del bloque o sistema cuando el actual esté completamente verificado.

No se avanza únicamente porque una modificación “parezca funcionar”.

Se avanza cuando el estado alcanzado está suficientemente comprobado.

---

No modifiques `AGENTS.md`, `docs/ARCHITECTURE.md` ni ningún otro archivo en esta tarea.

Después de crear `docs/WORKFLOW.md`:

1. inspecciona el archivo resultante;
2. confirma que coincide con esta especificación;
3. comprueba que no se haya modificado ningún otro archivo;
4. ejecuta `git status --short`;
5. informa del resultado;
6. no hagas commit.
