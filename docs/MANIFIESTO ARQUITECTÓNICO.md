# Manifiesto arquitectónico de AI-APPS

AI-APPS construye aplicaciones móviles interactivas centradas en la actividad humana. Cada aplicación desarrolla su propia experiencia, realidad, estado y reglas. Los sistemas gobiernan las actividades, las capacidades resuelven necesidades funcionales y la inteligencia artificial puede intervenir en cualquier tarea que lo requiera.

---

Este manifiesto fija las invariantes estructurales del repositorio al crecer.

La definición de AI-APPS, sus responsabilidades arquitectónicas y su ontología operacional están establecidas en el contexto del proyecto.

## Raíz compartida

AI-APPS mantiene una única raíz modular compartida.

Los sistemas y aplicaciones crecen dentro de esa raíz.

Una nueva aplicación reutiliza los componentes existentes cuando sus responsabilidades corresponden; no recibe copias de ellos.

La jerarquía física puede expresar pertenencia lógica real cuando exista. Los sistemas no necesitan ocupar todos el mismo nivel ni compartir la misma estructura interna.

Las herramientas autónomas y transversales del proyecto se alojan en `tools/`.

## Dependencias

`core/` proporciona fundamentos técnicos compartidos y no depende de los sistemas, capacidades ni aplicaciones concretas.

`ai/` puede depender de `core/`, pero no conoce las reglas particulares de los sistemas ni de las aplicaciones.

`systems/` puede depender de `core/` y define los contratos de sus necesidades funcionales sin depender de sus implementaciones concretas.

`capabilities/` puede depender de los contratos de los sistemas cuyas necesidades satisface y utilizar `ai/` u otros mecanismos cuando corresponda.

Los sistemas no dependen de implementaciones concretas de `ui/`, proveedores de IA ni capacidades funcionales.

Los sistemas pueden coexistir sin conocerse entre sí.

Los modelos, prompts y procedimientos de IA pueden incorporarse, combinarse, sustituirse o retirarse sin imponer cambios innecesarios a las reglas de las actividades.

Ninguna operación está obligada a atravesar `capabilities/` ni a utilizar inteligencia artificial cuando no lo necesita.

`apps/` realiza las conexiones concretas entre sistemas, capacidades, interfaces e implementaciones técnicas.

Las herramientas pueden observar las ejecuciones de los sistemas y aplicaciones, pero no gobiernan sus actividades ni redefinen sus reglas.

## Crecimiento

Las abstracciones compartidas se extraen cuando existe una necesidad real de reutilización.

La estructura física refleja responsabilidades existentes, no productos hipotéticos.

El árbol evoluciona mediante verticales funcionales.

Una responsabilidad existente se amplía o se extrae antes de duplicarse en otro lugar.