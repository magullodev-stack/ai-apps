# ÁRBOL DEL REPO — AI-APPS

AI-APPS es una plataforma para construir aplicaciones móviles interactivas de creación, descubrimiento y aprendizaje.

Este árbol establece la organización física de la plataforma y las responsabilidades de sus componentes.

La estructura crece conforme aparecen necesidades reales, sin anticipar las implementaciones particulares de los juegos.

---

## Raíz

ai-apps/
│
├── AGENTS.md                 # Instrucciones de trabajo para agentes.
│
├── apps/                     # Aplicaciones construidas sobre AI-APPS.
│
├── ai/                       # Subsistema técnico transversal de IA y cliente móvil.
│
├── shared/                   # Base común de las aplicaciones móviles.
│   └── ui/                   # Identidad visual, interfaz y componentes comunes.
│
├── tools/                    # Herramientas autónomas de AI-APPS.
│
└── docs/
    ├── MANIFIESTO ARQUITECTÓNICO.md
    ├── IA.md
    ├── ÁRBOL DEL REPO.md
    └── HERRAMIENTAS.md

---

## Responsabilidades

### apps/

Contiene las aplicaciones desarrolladas sobre AI-APPS.

Cada aplicación incorpora su propia realidad, estado, reglas, mecánicas y capacidades particulares.

Las aplicaciones utilizan la base común sin duplicar sus implementaciones.

Su organización interna se establece conforme a las necesidades de cada experiencia.

### ai/

Contiene el subsistema técnico transversal de inteligencia artificial.

Proporciona los mecanismos comunes necesarios para ejecutar operaciones de IA mediante los modelos y procedimientos que correspondan.

Incluye los mecanismos JVM recuperados bajo `ai/core/`, un puente HTTP local y el cliente reutilizable `ai/flutter_client/`.

Su organización interna responde a los mecanismos técnicos efectivamente implementados.

Las tareas particulares y sus instrucciones pertenecen a los componentes responsables de ellas.

### shared/

Contiene los fundamentos técnicos y componentes comunes que permiten construir las aplicaciones móviles de AI-APPS.

Proporciona la base reutilizable sin establecer la realidad, las reglas ni las mecánicas particulares de los juegos.

Su estructura interna crece conforme aparecen responsabilidades compartidas.

#### shared/ui/

Contiene la identidad visual y la interfaz común de AI-APPS.

Proporciona los estilos, componentes, navegación y elementos generales de interacción que utilizan las aplicaciones.

Cada juego incorpora únicamente las interfaces e interacciones particulares que necesita para desarrollar su experiencia.

### tools/

Contiene las herramientas autónomas y transversales de AI-APPS.

Cada herramienta dispone de su propia organización e implementación conforme a la función que desempeña.

### docs/

Contiene las fuentes de verdad y la documentación técnica de AI-APPS.

Cada documento establece su responsabilidad sin duplicar las definiciones de los demás.

---

## Crecimiento

El árbol canónico establece las responsabilidades y ubicaciones de los componentes, no obliga a crear directorios vacíos.

La base común se implementa hasta permitir construir, ejecutar y desarrollar una aplicación que incorpore su propia experiencia.

A partir de ese punto, las aplicaciones crecen mediante verticales funcionales completas.

Cada nueva necesidad se incorpora al componente responsable.

Las implementaciones comunes se reutilizan y las responsabilidades particulares permanecen en las aplicaciones correspondientes.

Una responsabilidad existente se amplía o se extrae antes de duplicarse.
