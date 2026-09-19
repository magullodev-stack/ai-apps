ai-apps/
├── core/                                      # Mecanismos y capacidades técnicas neutrales respecto al significado de los sistemas.
│   ├── contracts/                             # Mecanismos compartidos para expresar contratos técnicos.
│   ├── config/                                # Mecanismos compartidos para obtener configuración técnica.
│   ├── network/                               # Capacidad compartida de comunicación por red.
│   └── ai/                                    # Capacidad compartida para ejecutar operaciones mediante modelos de IA.
│
├── systems/                                   # Árbol semántico: aquí viven los sistemas y las relaciones de pertenencia entre ellos.
│   ├── knowledge/                             # Sistema que gobierna qué conocimiento resulta admisible para su uso.
│   └── games/                                 # Ámbito semántico al que pertenecen los sistemas de juego.
│       └── quiz10/                            # Sistema que gobierna una partida Quiz10.
│
├── ui/                                        # Implementaciones que proyectan estado y convierten interacción en acciones.
│   └── quiz10-web/                            # Presentación web actual de Quiz10.
│
├── apps/                                      # Composiciones ejecutables que conectan efectos con capacidades concretas.
│   ├── quiz10/                                # Composición ejecutable actual de Quiz10.
│   └── quiz10-web/                            # Composición ejecutable actual de Quiz10 con su interfaz web.
│
├── docs/                                      # Documentación propia del repositorio.
├── .devcontainer/                             # Definición del entorno aislado del repositorio.
├── .github/                                   # Integración del repositorio con GitHub.
├── gradle/                                    # Infraestructura del build Gradle.
├── build.gradle.kts                           # Configuración común del build.
├── settings.gradle.kts                        # Módulos que forman actualmente el build.
├── gradle.properties                          # Propiedades del build.
├── gradlew                                    # Wrapper de Gradle para Unix.
└── gradlew.bat                                # Wrapper de Gradle para Windows.