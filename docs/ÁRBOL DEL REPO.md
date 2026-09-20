Lectura del árbol: AI-APPS comparte una arquitectura común, pero cada aplicación móvil crece con su propia estructura, según las experiencias y responsabilidades que necesita.

ai-apps/
├── AGENTS.md                          # Guía de trabajo para agentes.
│
├── core/                              # Capacidades técnicas compartidas; no gobiernan actividades.
│   ├── contracts/                     # Contratos técnicos.
│   ├── config/                        # Configuración técnica.
│   ├── network/                       # Comunicación por red.
│   ├── ai/                            # Ejecución técnica de operaciones mediante modelos de IA.
│   ├── realtime/                      # Transporte de mensajes y actualizaciones en vivo. [FUTURO]
│   └── persistence/                   # Almacenamiento y recuperación técnica.
│
├── systems/                           # Realidad, significado, estado y reglas de las actividades.
│   ├── knowledge/                     # Conocimiento compartido, cuando exista una responsabilidad común real.
│   │
│   ├── games/
│   │   ├── quiz10/                    # Suite interactiva de conocimiento, juego y aprendizaje mediante experiencias individuales y sociales basadas en preguntas.
│   │   │   │
│   │   │   ├── rooms/                 # Salas persistentes que reúnen personas y actividades.
│   │   │   │   ├── membership/        # Pertenencia, invitaciones y acceso a una sala.
│   │   │   │   ├── conversation/      # Conversación y acontecimientos de la sala.
│   │   │   │   └── challenges/        # Tests de la sala: disponibilidad,
│   │   │   │                          # desbloqueos, participación y resultados.
│   │   │   │
│   │   │   ├── duels/                 # Encuentros 1 vs. 1 y sus reglas de competición.
│   │   │   │
│   │   │   ├── quick-play/            # Partidas inmediatas y aleatorias.
│   │   │   │
│   │   │   ├── study/                 # Actividades de aprendizaje, explicación y repaso.
│   │   │   │
│   │   │   ├── quiz/                  # Responsabilidades de contenido y resolución
│   │   │   │   │                      # reutilizables por las experiencias que las necesiten.
│   │   │   │   ├── topics/            # Tema y enfoque de una actividad de preguntas.
│   │   │   │   ├── coverage/          # Preparación de conocimiento cuando se requiera
│   │   │   │   │                      # una ruta de cobertura.
│   │   │   │   └── question/          # Preguntas, respuestas y criterios de admisibilidad.
│   │   │   │
│   │   │   └── progress/              # Progreso y logros con significado
│   │   │                              # más allá de una actividad concreta.
│   │   │
│   │   ├── molecular/                 # Experiencias de construcción y exploración molecular. [FUTURO]
│   │   ├── music/                     # Experiencias de composición y exploración musical. [FUTURO]
│   │   └── semantic-math/             # Experiencias de exploración semántico-matemática. [FUTURO]
│   │
│   └── cuina/                         # Experiencia culinaria y continuidad de la elaboración.
│       ├── preferences/               # Preferencias, restricciones y equipamiento. [FUTURO]
│       ├── families/                  # Familias de elaboración y sus criterios. [FUTURO]
│       ├── recipes/                   # Recetas, cantidades y adaptaciones. [FUTURO]
│       └── cooking/                   # Elaboración en curso y progreso. [FUTURO]
│
├── ui/                                # Presentación e interacción de las aplicaciones móviles.
│   ├── quiz10/                        # Interfaz móvil de la suite Quiz10.
│   │   ├── home/                      # Entrada a las experiencias.
│   │   ├── rooms/                     # Descubrimiento y experiencia dentro de las salas.
│   │   ├── duels/                     # Experiencia de enfrentamiento 1 vs. 1.
│   │   ├── quick-play/                # Entrada y desarrollo de partidas inmediatas.
│   │   ├── study/                     # Experiencia de aprendizaje y repaso.
│   │   └── shared/                    # Presentación reutilizable cuando realmente corresponda.
│   │
│   └── cuina/                         # Interfaz móvil de la experiencia culinaria. [FUTURO]
│
├── apps/                              # Composición ejecutable de las aplicaciones móviles.
│   ├── quiz10/                        # Composición móvil de la suite Quiz10.
│   └── cuina/                         # Composición móvil de Cuina. [FUTURO]
│
├── tools/                             # Herramientas autónomas y transversales de AI-APPS.
│   └── monitor/                       # Observación, análisis e informes de consumo, costes,
│       │                              # rendimiento y auditorías de las ejecuciones de AI-APPS.
│       └── README.md                  # Documentación de la herramienta MONITOR.
│
├── docs/
│   ├── MANIFIESTO ARQUITECTÓNICO.md   # Arquitectura global.
│   ├── IA.md                          # Papel de la inteligencia artificial.
│   ├── ÁRBOL DEL REPO.md              # Organización del repositorio.
│   └── HERRAMIENTAS.md                # Catálogo de herramientas y ubicación de sus manuales.
│
├── .devcontainer/
├── .github/
├── gradle/
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
├── gradlew
└── gradlew.bat