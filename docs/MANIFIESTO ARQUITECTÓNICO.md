# Manifiesto arquitectónico de AI-APPS

AI-APPS es una plataforma para construir aplicaciones móviles interactivas de creación, descubrimiento y aprendizaje.

Cada aplicación desarrolla su propia experiencia, realidad, estado y reglas. Los sistemas gobiernan las actividades, las capacidades resuelven necesidades funcionales y la inteligencia artificial puede intervenir en cualquier tarea que lo requiera.

Este manifiesto establece las invariantes estructurales del repositorio. La ontología operacional y el funcionamiento de la inteligencia artificial se definen en sus documentos correspondientes.

---

## Raíz compartida

AI-APPS mantiene una única raíz modular compartida, organizada en cinco troncales:

### `apps/` — Aplicaciones

Contiene las aplicaciones móviles de AI-APPS.

Cada aplicación integra sus sistemas, capacidades particulares, interfaces y composición ejecutable.

Cada aplicación desarrolla su propia estructura interna según las experiencias y responsabilidades que necesita.

### `ai/` — Inteligencia artificial

Contiene el subsistema técnico transversal de inteligencia artificial.

Proporciona los mecanismos de ejecución, integración con modelos y proveedores, configuración técnica y observabilidad, sin conocer las reglas particulares de las aplicaciones.

Los prompts y procedimientos específicos de cada tarea pertenecen al componente responsable de esa tarea.

### `shared/` — Componentes compartidos

Contiene los fundamentos técnicos, componentes visuales, sistemas y capacidades que tienen una responsabilidad compartida.

Cada componente mantiene su propia responsabilidad y puede ser utilizado por las aplicaciones que lo necesiten.

Las implementaciones compartidas se reutilizan sin duplicarse en cada aplicación.

### `tools/` — Herramientas

Contiene las herramientas autónomas y transversales de AI-APPS.

Proporcionan funciones de desarrollo, análisis, observación y operación de la plataforma.

Las herramientas pueden observar las ejecuciones de las aplicaciones y sus sistemas, pero no gobiernan sus actividades ni redefinen sus reglas.

### `docs/` — Documentación

Contiene la documentación que define y describe AI-APPS.

Incluye la ontología operacional, el manifiesto arquitectónico, el funcionamiento de la inteligencia artificial, la organización del repositorio y las decisiones técnicas de la plataforma.

Cada documento mantiene su responsabilidad como fuente de verdad.

---

## Dependencias

Los sistemas gobiernan sus actividades y definen los contratos de sus necesidades funcionales sin depender de implementaciones concretas.

Las capacidades satisfacen esas necesidades mediante los mecanismos que correspondan.

Las interfaces representan la realidad de las actividades y permiten interactuar con ella sin asumir el gobierno de sus reglas.

Las aplicaciones conectan los sistemas, capacidades, interfaces e implementaciones técnicas que necesitan.

Los componentes compartidos mantienen sus responsabilidades y contratos independientemente de las aplicaciones que los utilizan.

Los sistemas pueden coexistir sin conocerse entre sí.

Ninguna operación está obligada a utilizar una capacidad externa ni inteligencia artificial cuando no lo necesita.

---

## Construcción y crecimiento

AI-APPS crece mediante experiencias y verticales funcionales completas.

Cada nueva aplicación incorpora sus responsabilidades particulares y reutiliza las implementaciones compartidas cuando corresponda.

Las abstracciones compartidas se extraen cuando existe una necesidad real de reutilización.

Una responsabilidad existente se amplía o se extrae antes de duplicarse en otro lugar.

La estructura física expresa responsabilidades y pertenencias reales, sin imponer una organización interna uniforme a todas las aplicaciones.

La plataforma evoluciona conforme aparecen nuevas necesidades, sin anticipar componentes, funcionalidades ni productos hipotéticos.