ai-apps/
├── core/                              # Capacidades técnicas compartidas; no gobiernan actividades.
│   ├── contracts/                     # Contratos técnicos.
│   ├── config/                        # Configuración técnica.
│   ├── network/                       # Comunicación por red.
│   ├── ai/                            # Ejecución técnica de operaciones mediante modelos de IA.
│   ├── realtime/                      # Transporte de mensajes y actualizaciones en vivo. [FUTURO]
│   └── persistence/                   # Almacenamiento y recuperación técnica.
│
├── systems/                           # Realidad, significado, estado y reglas de las actividades.
│   ├── knowledge/                     # Responsabilidades de conocimiento realmente compartidas.
│   │
│   ├── games/
│   │   ├── quiz10/                    # Experiencias de preguntas, estudio y competición.
│   │   │   │
│   │   │   ├── topics/                # Tema y enfoque de la actividad; usa clasificación
│   │   │   │                          # compartida si existe, sin duplicar sus reglas.
│   │   │   ├── coverage/              # Rutas de conocimiento utilizables por las modalidades.
│   │   │   ├── question/              # Preguntas, respuestas y criterios de admisibilidad.
│   │   │   ├── preparation/           # Preparación de actividades y sus resultados admisibles.
│   │   │   ├── session/               # Estado y transiciones compartidos de una partida.
│   │   │   ├── progress/              # Resultados y progreso entre actividades.
│   │   │   ├── interaction/           # Intervenciones comunes a Quiz10, cuando existan.
│   │   │   │
│   │   │   └── modes/                 # Reglas propias de cada forma de participar.
│   │   │       ├── quick-play/        # Partida rápida. [FUTURO]
│   │   │       ├── study/             # Aprendizaje, explicaciones y repaso. [FUTURO]
│   │   │       ├── arcade/            # Competición 1 vs. 1 y tiempo de partida. [FUTURO]
│   │   │       └── group/             # Sala, participantes y desafíos en grupo. [FUTURO]
│   │   │
│   │   ├── molecular/                 # Construcción y exploración molecular. [FUTURO]
│   │   ├── music/                     # Composición y exploración musical. [FUTURO]
│   │   └── semantic-math/             # Exploración semántico-matemática. [FUTURO]
│   │
│   └── cuina/                         # Experiencia culinaria y continuidad de la elaboración.
│       ├── preferences/               # Preferencias, restricciones y equipamiento. [FUTURO]
│       ├── families/                  # Familias de elaboración y sus criterios. [FUTURO]
│       ├── recipes/                   # Recetas, cantidades y adaptaciones. [FUTURO]
│       ├── cooking/                   # Elaboración en curso y progreso de los pasos. [FUTURO]
│       └── interaction/               # Acompañamiento común de Cuina, cuando exista. [FUTURO]
│
├── ui/                                # Experiencias visibles: escenas, controles y navegación.
│   ├── quiz10-web/                    # Interfaz web de Quiz10 y sus modalidades.
│   └── cuina-web/                     # Exploración de platos y cocina en curso. [FUTURO]
│
├── apps/                              # Composiciones ejecutables de sistemas, UI y capacidades.
│   ├── quiz10/                        # Composición actual de Quiz10.
│   ├── quiz10-web/                    # Composición web actual; futura conexión de sus
│   │                                  # modalidades y actualizaciones en vivo.
│   └── cuina-web/                     # Composición ejecutable de Cuina. [FUTURO]
│
├── docs/
├── .devcontainer/
├── .github/
├── gradle/
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
├── gradlew
└── gradlew.bat