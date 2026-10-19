# ÁRBOL DEL REPO — AI-APPS

AI-APPS es una plataforma para construir aplicaciones interactivas con inteligencia artificial.

Este documento refleja la organización actual del repositorio y la pertenencia general de sus componentes.

---

## Raíz

ai-apps/
│
├── .ai-apps/                  # Datos internos de trabajo y desarrollo.
├── .vscode/                   # Configuración local de VS Code.
├── AGENTS.md                  # Instrucciones de trabajo para agentes.
│
├── apps/                      # Aplicaciones construidas sobre AI-APPS.
│   └── muondia/
│       ├── lib/
│       │   ├── main.dart
│       │   ├── app/           # Estructura general de Muondia.
│       │   │   ├── auth/        # Entrada y UI de autenticación propia de Muondia.
│       │   │   ├── development/ # Catálogo y vistas previsualizables de Muondia.
│       │   │   ├── interaction/ # Presentación de intervenciones de Muondia.
│       │   │   └── onboarding/  # Recorrido inicial obligatorio tras el registro.
│       │   │       ├── interaction/ # Pantallas y animaciones de bienvenida.
│       │   │       └── production/  # Generación y validación de diez preguntas.
│       │   ├── modes/         # Experiencias accesibles desde Home.
│       │   │   └── estudio/
│       │   ├── coverage/      # Estructuras de cobertura factual.
│       │   └── semantic_catalog/ # Catálogo semántico.
│       │
│       ├── assets/
│       ├── tool/              # Herramientas y verificadores de Muondia.
│       ├── android/
│       ├── README.md
│       └── run.ps1            # Lanzador de Muondia.
│
├── ai/                        # Infraestructura técnica compartida de IA.
│   ├── dart_service/
│   ├── flutter_client/
│   └── README.md
│
├── shared/                    # Componentes compartidos de AI-APPS.
│   ├── identity/              # Identidad y autenticación compartidas.
│   └── ui/                    # Componentes de interfaz reutilizables.
│
├── scripts/                   # Herramientas operativas compartidas.
│   ├── install-git-sync.ps1    # Instala sincronizacion Git de Windows (solo Git).
│   ├── auto-sync-dev.ps1      # Git continuo; no inicia Android ni Flutter.
│   ├── android-session.ps1    # Registro y consulta de aplicaciones Android.
│   ├── android/               # Registro de sesiones y comandos ADB.
│   ├── sync-dev.ps1
│   ├── embedroid/               # EmbeDroid mantenido, paquete base y pruebas.
│   ├── install-embedroid.ps1     # Instala el visor corregido y la integración.
│   └── vscode-android/        # Extensión VS Code y Explorador de experiencias.
│
├── docs/                      # Documentación general de AI-APPS.
│   ├── MANIFIESTO ARQUITECTÓNICO.md
│   ├── IA.md
│   ├── ÁRBOL DEL REPO.md
│   └── HERRAMIENTAS.md
│
├── analizar-pivotes.ps1
├── evaluar-dimensiones.ps1
└── generar-pivotes.ps1

---

## Zonas

### apps/

Contiene las aplicaciones construidas sobre AI-APPS.

Cada aplicación mantiene en su propio espacio la estructura necesaria para desarrollar su experiencia.

### ai/

Contiene la infraestructura técnica compartida para ejecutar operaciones de inteligencia artificial.

Su funcionamiento se documenta en [`ai/README.md`](../ai/README.md).

### shared/

Contiene componentes compartidos por las aplicaciones cuando existe una necesidad real de reutilización.

`shared/identity/` contiene la capacidad técnica común de identidad y autenticación. `shared/ui/` contiene componentes de interfaz reutilizables.

### scripts/

Contiene las herramientas del entorno. `auto-sync-dev.ps1` sincroniza
Git independientemente de Muondia mediante la tarea Windows
`AI-APPS Git Sync`. Al abrir VS Code, `vscode-android/` inicia la
depuracion oficial Dart-Code con el prelanzamiento de
`apps/muondia/prepare-debug.ps1`, y conecta el Explorador de
experiencias y el visor. `android/` registra aplicaciones y consulta
ADB, pero no ejecuta workers ni un runner Flutter propio.
`embedroid/` mantiene el visor integrado y `install-embedroid.ps1`
instala las extensiones necesarias. Los registros locales siguen en
`.ai-apps/`, fuera de Git.

### docs/

Contiene la documentación general de AI-APPS.

### .ai-apps/

Contiene datos internos utilizados durante el desarrollo, las pruebas y la experimentación.
