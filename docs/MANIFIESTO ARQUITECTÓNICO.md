# 📝 Manifiesto arquitectónico de ai-apps

Este repositorio es una raíz modular compartida para múltiples sistemas y aplicaciones.

La arquitectura separa cuatro responsabilidades:

- `core/` → capacidades técnicas reutilizables;
- `systems/` → lógica, reglas y dominios;
- `ui/` → presentación e interacción;
- `apps/` → composición ejecutable.

La estructura física principal es:

./
├── core/
├── systems/
├── ui/
├── apps/
└── docs/

Las aplicaciones crecen dentro de este mismo árbol.

No copian el core.

No parten de plantillas que después divergen.

---

# core

`core/` contiene mecanismos técnicos neutrales respecto a los productos.

Puede incluir:

- contratos;
- configuración;
- red;
- serialización;
- IA;
- persistencia;
- autenticación;
- identidad;
- seguridad;
- almacenamiento;
- localización;
- tiempo;
- telemetría;
- logging;
- recuperación técnica ante fallos.

`core` conoce el cómo técnico.

No conoce reglas de producto.

Una capacidad pertenece a `core` cuando puede existir sin conocer el significado que tendrá dentro de un sistema concreto.

---

# systems

`systems/` contiene la lógica que da significado al software.

Cada sistema puede definir:

- modelos de dominio;
- estados;
- reglas;
- procesos;
- transiciones;
- invariantes;
- validaciones;
- decisiones;
- resultados;
- políticas;
- uso semántico de capacidades de `core`.

Los sistemas pueden utilizar `core`.

`core` no depende de ellos.

Dos sistemas pueden compartir capacidades técnicas sin conocerse entre sí.

Las abstracciones comunes se extraen cuando existe reutilización real, no para anticipar productos futuros.

---

# ui

`ui/` convierte estados y operaciones de los sistemas en interacción visible.

Puede contener:

- pantallas;
- componentes;
- navegación;
- controles;
- layouts;
- temas;
- animaciones;
- recursos visuales;
- representación de carga y errores;
- adaptación a dispositivos.

`ui` representa estado y comunica acciones del usuario.

No redefine las reglas del sistema.

Los componentes compartidos se extraen cuando existe reutilización real.

---

# apps

`apps/` contiene las composiciones ejecutables.

Una aplicación decide:

- qué sistemas utiliza;
- qué UI incorpora;
- qué implementaciones técnicas conecta;
- qué configuración carga;
- qué servicios inicia;
- qué puntos de entrada expone.

`apps` ensambla.

No duplica responsabilidades de `core`, `systems` o `ui`.

Conceptualmente:

**core + systems + ui → aplicación**

---

# Dependencias e invariantes

La dirección conceptual de dependencias es:

**ui → systems → core**

La composición conecta las implementaciones:

**apps → core + systems + ui**

Se mantienen estas reglas:

1. `core` permanece neutral respecto a sistemas y aplicaciones.
2. Las reglas de dominio pertenecen a `systems`.
3. `ui` representa e interactúa, pero no gobierna el dominio.
4. `apps` compone; no duplica lógica.
5. `systems` puede utilizar `core`, pero `core` no depende de `systems`.
6. `systems` no depende de implementaciones visuales concretas.
7. Los sistemas pueden coexistir sin conocerse entre sí.
8. Una nueva aplicación utiliza la raíz existente; no recibe una copia del core.
9. Los detalles de proveedores externos permanecen fuera de las reglas de dominio.
10. Las abstracciones compartidas aparecen por necesidad real.
11. El estado estructurado prevalece sobre sus representaciones.
12. El árbol se desarrolla por verticales funcionales, no completando carpetas por orden.

---

# Perfiles globales de IA

LUNA, MINI y TERRA son perfiles compartidos de `ai-apps`, no modelos propiedad de un sistema.

- `systems/` puede seleccionar el perfil que necesita.
- `systems/` no conoce identificadores concretos de modelo ni variables de entorno de modelos.
- `core/ai` es la única capa que resuelve el perfil solicitado contra `EnvironmentConfig.aiModels`.

Roles globales:

- LUNA → tareas ligeras, interfaz textual, reformulación, presentación y conversación simple.
- MINI → tareas intermedias que requieren cierta interpretación o criterio sin razonamiento fuerte.
- TERRA → tareas que requieren razonamiento fuerte sobre la entrada del usuario.

---

# Síntesis

**core proporciona capacidades.**

**systems les da significado.**

**ui las convierte en interacción.**

**apps las convierte en aplicaciones ejecutables.**

> **Una sola raíz compartida; múltiples sistemas y aplicaciones creciendo sobre ella sin duplicar el tronco común.**