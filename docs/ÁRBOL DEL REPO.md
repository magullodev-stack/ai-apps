# ÁRBOL DEL REPO — AI-APPS

AI-APPS es una plataforma para construir aplicaciones interactivas con inteligencia artificial.

Este árbol establece la organización de la plataforma y muestra cómo se integra un juego y cómo se distribuyen las responsabilidades entre su estructura general y sus modalidades.

Los nombres `juego/` y `modalidad/` del esquema son representativos: cada implementación utiliza su nombre real. El esquema no obliga a crear carpetas vacías ni a que todas las aplicaciones tengan modalidades.

---

## Raíz

ai-apps/
│
├── AGENTS.md                  # Instrucciones de trabajo para agentes.
│
├── apps/                      # Aplicaciones construidas sobre AI-APPS.
│   │
│   └── juego/                 # Un juego concreto.
│       │
│       ├── lib/
│       │   ├── main.dart       # Punto de entrada del juego.
│       │   │
│       │   ├── app/           # Identidad y experiencia general del juego.
│       │   │   ├── home/      # Pantalla principal y acceso a las modalidades.
│       │   │   ├── profile/   # Perfil, si el juego lo necesita.
│       │   │   └── settings/  # Configuración, si el juego la necesita.
│       │   │
│       │   └── modes/         # Modalidades que componen el juego.
│       │       └── modalidad/ # Experiencia particular de una modalidad.
│       │
│       ├── test/              # Pruebas del juego y de sus modalidades.
│       ├── tool/              # Herramientas particulares, cuando se necesitan.
│       └── android/           # Configuración Android del juego.
│
├── ai/                        # Subsistema técnico transversal de IA.
│   ├── dart_service/          # Servicio local Dart de IA.
│   └── flutter_client/        # Cliente móvil reutilizable.
│
├── shared/                    # Base común de las aplicaciones móviles.
│   └── ui/                    # Componentes de interfaz compartidos.
│
├── scripts/                   # Procedimientos de desarrollo y ejecución local.
│
└── docs/
    ├── MANIFIESTO ARQUITECTÓNICO.md
    ├── IA.md
    ├── ÁRBOL DEL REPO.md
    └── HERRAMIENTAS.md

---

## Responsabilidades

### apps/

Contiene las aplicaciones construidas sobre AI-APPS.

Cada aplicación desarrolla su propia experiencia y utiliza las capacidades técnicas de la plataforma que necesita.

Un juego puede organizarse en modalidades. En ese caso, el juego es la unidad que reúne la experiencia completa y cada modalidad es una parte de esa experiencia, no una aplicación independiente.

La organización interna de cada aplicación responde a sus necesidades reales. El esquema de un juego con modalidades no impone la misma estructura a todas las aplicaciones.

### apps/juego/

Representa un juego concreto construido sobre AI-APPS.

El juego es responsable de su identidad, su experiencia general y la integración de sus modalidades.

Su funcionamiento y su organización particular se documentan en el README del propio juego.

#### lib/app/

Contiene la estructura general del juego: identidad visual, pantalla principal, navegación y pantallas comunes.

La pantalla principal presenta las modalidades y permite acceder a ellas. No contiene las reglas ni el estado particular de sus partidas.

Los componentes generales pertenecen al juego mientras no exista una necesidad real de compartirlos con otras aplicaciones.

#### lib/modes/

Contiene las modalidades que forman parte del juego.

Cada modalidad tiene su propio espacio para implementar la experiencia que ofrece: interfaz, estado, reglas, mecánicas y necesidades funcionales.

Una modalidad utiliza la estructura general del juego sin mezclar su implementación particular con la de las demás modalidades.

Las modalidades se incorporan cuando se desarrollan. No se crean carpetas ni implementaciones para experiencias que todavía no existen.

#### lib/modes/modalidad/

Representa una modalidad concreta.

Contiene los componentes necesarios para desarrollar y gobernar su experiencia particular.

Si la modalidad utiliza inteligencia artificial, mantiene bajo su responsabilidad las instrucciones, los esquemas, las validaciones y las reglas que correspondan a su actividad. Para ejecutar las operaciones de IA utiliza las capacidades técnicas de la plataforma.

La inteligencia artificial puede participar en la experiencia sin sustituir al sistema que establece y gobierna sus reglas.

#### test/

Contiene las pruebas del juego y de sus modalidades, organizadas según la responsabilidad que verifican.

#### tool/

Contiene las herramientas particulares del juego cuando existe una necesidad real de utilizarlas.

---

### ai/

Contiene el subsistema técnico transversal de inteligencia artificial.

Proporciona los mecanismos comunes que las aplicaciones utilizan para realizar operaciones de IA.

`ai/dart_service/` contiene el servicio local Dart de IA.

`ai/flutter_client/` contiene el cliente móvil reutilizable que permite a las aplicaciones comunicarse con el servicio.

Los mecanismos técnicos comunes pertenecen a `ai/`. Las instrucciones, los esquemas, las validaciones y las reglas particulares de una experiencia permanecen en la aplicación o modalidad responsable de ella.

---

### shared/

Contiene los fundamentos técnicos y componentes que se reutilizan realmente entre aplicaciones.

No establece la identidad, la experiencia ni las reglas particulares de los juegos.

Su estructura crece conforme aparecen necesidades compartidas.

#### shared/ui/

Contiene los componentes de interfaz reutilizados entre aplicaciones.

Cada aplicación conserva sus pantallas, su navegación, su identidad visual y sus elementos de interacción particulares.

Un componente se incorpora a `shared/ui/` cuando existe una necesidad real de reutilización entre aplicaciones.

---

### scripts/

Contiene los procedimientos de desarrollo y ejecución local de AI-APPS.

Cada procedimiento responde a una necesidad operativa concreta y se documenta en el lugar correspondiente.

---

### docs/

Contiene la documentación arquitectónica y técnica de AI-APPS.

Describe la plataforma, sus componentes y sus responsabilidades.

El funcionamiento detallado de un juego, sus modalidades y su organización particular se documentan en el README del propio juego.

---

## Construcción y crecimiento

El árbol expresa las relaciones y responsabilidades de la plataforma, no una obligación de crear todos los directorios representados.

Cada aplicación crece conforme se desarrolla su experiencia. Si un juego incorpora una nueva modalidad, su implementación se integra dentro del propio juego y se mantiene separada de la estructura general y de las demás modalidades.

Las capacidades técnicas comunes se reutilizan cuando corresponde. Las responsabilidades particulares permanecen en la aplicación o modalidad que las necesita.

Una responsabilidad existente se amplía o se extrae antes de duplicarse. Los componentes compartidos se incorporan cuando existe una necesidad real de reutilización.

AI-APPS permite construir aplicaciones con experiencias diferentes sin imponerles una identidad visual, unas mecánicas ni una organización interna uniforme.