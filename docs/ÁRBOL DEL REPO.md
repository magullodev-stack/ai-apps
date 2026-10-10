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
│   └── quizai/
│       ├── lib/
│       │   ├── main.dart
│       │   ├── app/           # Estructura general de QuizAI.
│       │   │   ├── auth/        # Entrada y UI de autenticación propia de QuizAI.
│       │   │   ├── interaction/ # Presentación de intervenciones de QuizAI.
│       │   │   └── onboarding/  # Secuencias iniciales de la aplicación.
│       │   ├── modes/         # Modalidades de QuizAI.
│       │   │   ├── estudio/
│       │   │   └── quiz10/
│       │   │       ├── interaction/ # Experiencia e interacción de Quiz10.
│       │   │       └── production/  # Producción y validación de sus tests.
│       │   ├── coverage/      # Estructuras de cobertura factual.
│       │   └── semantic_catalog/ # Catálogo semántico.
│       │
│       ├── assets/
│       ├── tool/              # Herramientas y verificadores de QuizAI.
│       ├── android/
│       ├── README.md
│       └── run.ps1            # Lanzador de QuizAI.
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
│   ├── install-dev-session.ps1 # Instala la tarea de Windows por usuario.
│   ├── start-dev-session.ps1   # Entrada mínima de la sesión persistente.
│   ├── start-ai-apps-android.ps1 # Prepara emulator-5554.
│   ├── flutter-dev-runner.dart # Vigila archivos y aplica Hot Reload.
│   ├── start-android.ps1
│   ├── sync-dev.ps1
│   └── vscode-android/
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

Contiene procedimientos y herramientas operativas compartidas por el repositorio. La tarea `AI-APPS Development` ejecuta `start-dev-session.ps1` al iniciar sesión; este reutiliza primero el preparador Android y después el lanzador de QuizAI. `vscode-android/` solo abre EmbeDroid sobre el dispositivo existente.

### docs/

Contiene la documentación general de AI-APPS.

### .ai-apps/

Contiene datos internos utilizados durante el desarrollo, las pruebas y la experimentación.