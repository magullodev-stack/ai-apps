# Manifiesto arquitectónico de AI-APPS

AI-APPS es una plataforma para construir aplicaciones interactivas con inteligencia artificial.

Cada aplicación desarrolla su propia experiencia, realidad, estado y reglas. Los sistemas gobiernan las actividades, las capacidades resuelven necesidades funcionales y la inteligencia artificial puede intervenir en cualquier tarea que lo requiera.

Este manifiesto establece las invariantes estructurales del repositorio. La organización del repositorio y el funcionamiento de la inteligencia artificial se definen en sus documentos correspondientes.

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