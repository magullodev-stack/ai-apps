# Manifiesto arquitectónico de AI-APPS

Este manifiesto fija las invariantes estructurales del repositorio al crecer.

La definición de AI-APPS, sus responsabilidades arquitectónicas y su ontología operacional están establecidas en el contexto del proyecto.

## Raíz compartida

AI-APPS mantiene una única raíz modular compartida.

Los sistemas y aplicaciones crecen dentro de esa raíz.

Una nueva aplicación utiliza las capacidades y sistemas existentes; no recibe copias de ellos.

La jerarquía física puede expresar pertenencia lógica real cuando exista. Los sistemas no necesitan ocupar todos el mismo nivel.

## Dependencias

`systems/` puede depender de `core/`.

`core/` no depende de `systems/`.

`systems/` no depende de implementaciones concretas de `ui/`.

Los sistemas pueden coexistir sin conocerse entre sí.

Los detalles de proveedores externos permanecen fuera de las reglas de dominio.

`apps/` realiza las conexiones concretas entre efectos y capacidades.

## Crecimiento

Las abstracciones compartidas se extraen cuando existe una necesidad real de reutilización.

La estructura física refleja responsabilidades existentes, no productos hipotéticos.

El árbol evoluciona mediante verticales funcionales.

Una responsabilidad existente se amplía o se extrae antes de duplicarse en otro lugar.