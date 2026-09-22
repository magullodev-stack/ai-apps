# ÁRBOL DEL REPO — AI-APPS

Lectura del árbol: AI-APPS es una plataforma para construir aplicaciones móviles interactivas con inteligencia artificial. Cada aplicación desarrolla su propia experiencia, realidad, estado y reglas. Los sistemas gobiernan las actividades, las capacidades resuelven necesidades funcionales y el subsistema de IA permite utilizar cualquier modelo para cualquier tarea que lo requiera. Cada aplicación crece con su propia estructura, según las experiencias y responsabilidades que necesita.

Estado: las carpetas preparadas con `.gitkeep` todavía no contienen una implementación. El código técnico existente de IA se conserva en `ai/src/`. MONIT-AI conserva temporalmente su código fuera de la compilación activa.

ai-apps/
│
├── AGENTS.md                          # Guía de trabajo para agentes.
│
├── core/                              # Fundamentos técnicos compartidos.
│   ├── contracts/                     # Contratos técnicos comunes.
│   ├── config/                        # Configuración técnica.
│   └── network/                       # Comunicación por red.
│
├── ai/                                # Subsistema técnico de inteligencia artificial.
│   ├── runtime/                       # Ejecución de operaciones de IA.
│   ├── providers/                     # Integraciones con proveedores de modelos.
│   │   └── openai/                    # Implementación del proveedor OpenAI.
│   └── observability/                 # Registro técnico de ejecuciones,
│                                      # consumo, costes, errores y auditorías.
│
├── systems/                           # Realidad, significado, estado y reglas
│   │                                  # de las actividades.
│   │
│   └── games/
│       └── quiz10/                    # Sistema de juego y aprendizaje Quiz10.
│           │
│           ├── modes/                 # Modalidades y sus reglas específicas.
│           │   ├── random/       # Partidas inmediatas y aleatorias.
│           │   ├── duels/             # Enfrentamientos entre jugadores.
│           │   ├── study/             # Actividades de aprendizaje y repaso.
│           │   └── rooms/             # Salas y actividades sociales.
│           │
│           ├── questions/             # Preguntas jugables, respuestas,
│           │                          # requisitos y contratos de obtención.
│           │
│           ├── session/               # Estado, desarrollo y resultados
│           │                          # de las partidas.
│           │
│           └── progress/              # Progreso y logros de los jugadores.
│
├── capabilities/                      # Capacidades funcionales de las aplicaciones.
│   └── quiz10/
│       └── questions/                 # Preparación de contenido jugable para Quiz10.
│           └── prompts/               # Instrucciones específicas de las tareas
│                                      # de preparación de preguntas.
│
├── apps/                              # Composición ejecutable de las aplicaciones móviles.
│   └── quiz10/                        # Composición móvil de Quiz10.
│
├── ui/                                # Presentación e interacción de las aplicaciones móviles.
│   └── quiz10/                        # Interfaz móvil de Quiz10.
│
├── tools/                             # Herramientas autónomas de AI-APPS.
│   └── monit-ai/                      # Observación, análisis e informes de consumo,
│       └── README.md                  # costes, rendimiento y auditorías.
│
├── docs/
│   ├── MANIFIESTO ARQUITECTÓNICO.md   # Arquitectura global.
│   ├── IA.md                          # Papel de la inteligencia artificial.
│   ├── ÁRBOL DEL REPO.md              # Organización del repositorio.
│   └── HERRAMIENTAS.md                # Catálogo de herramientas y manuales.
│
├── .devcontainer/
├── .github/
├── gradle/
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
├── gradlew
└── gradlew.bat