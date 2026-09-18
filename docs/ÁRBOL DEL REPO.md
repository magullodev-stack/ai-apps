ai-apps/
├── core/                                  # Base técnica neutral compartida
│   ├── contracts/                         # Contratos técnicos comunes
│   ├── config/                            # Configuración y entorno
│   ├── network/                           # Transporte y comunicación
│   ├── ai/                                # Acceso técnico a modelos/proveedores de IA
│   ├── persistence/                       # Persistencia genérica
│   ├── auth/                              # Autenticación
│   ├── identity/                          # Identidad
│   ├── localization/                      # Localización
│   ├── security/                          # Seguridad y secretos
│   ├── telemetry/                         # Telemetría y observabilidad
│   ├── time/                              # Tiempo y temporización
│   └── ...                                # Otras capacidades técnicas neutrales
│
├── systems/                               # Sistemas de comportamiento y dominio
│   ├── <Sistema>/
│   │   ├── ...                            # Reglas, estado, procesos y datos del sistema
│   │   └── ...
│   └── ...                                # Más sistemas independientes
│
├── ui/                                    # Materialización visible e interactiva
│   ├── screens/                           # Pantallas y vistas completas
│   │   └── ...
│   ├── shared/                            # Componentes reutilizables reales
│   │   └── ...
│   └── ...                                # Otras formas de presentación cuando aparezcan
│
├── apps/                                  # Composición de aplicaciones concretas
│   ├── <App>/
│   │   ├── ...                            # Entrada, ensamblaje y configuración de esa app
│   │   └── ...
│   └── ...                                # Más aplicaciones construidas sobre el mismo árbol
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