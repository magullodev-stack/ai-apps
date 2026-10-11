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
├── agent-lab/                 # Laboratorio independiente ChatDev 2.0 → Codex.
│   ├── workflows/             # Agente deliberador y grafo de delegación y retorno.
│   ├── config/                # Configuración del planificador sin credenciales.
│   ├── prompts/               # Esquema validado de decisiones del agente.
│   ├── examples/              # Código de ejemplo para ejecuciones aisladas.
│   ├── tests/                 # Pruebas offline del ciclo con ChatDev real.
│   ├── install.ps1            # Instala dependencias locales fijadas.
│   ├── run.ps1                # Ejecuta una instrucción y conserva artefactos.
│   ├── android.ps1            # Asociación y control Android por experimento.
│   ├── lab_android.py         # Adaptador al gestor y evidencia por ciclo.
│   ├── vision.py              # Capturas, adjuntos y evaluación multimodal por ciclo.
│   ├── uninstall.ps1          # Retira instalación o laboratorio completo.
│   └── README.md              # Operación, aislamiento e inspección.
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
│   ├── start-ai-apps-android.ps1 # Prepara el AVD de cada sesión; por defecto emulator-5554.
│   ├── android-session.ps1      # Registro, consulta y control independiente de sesiones.
│   ├── android/                # Workers, registro y pruebas multiemulador.
│   ├── flutter-dev-runner.dart # Vigila archivos y aplica Hot Reload.
│   ├── start-android.ps1
│   ├── sync-dev.ps1
│   ├── embedroid/               # EmbeDroid mantenido, paquete base y pruebas.
│   ├── install-embedroid.ps1     # Instala el visor corregido y la integración.
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

### agent-lab/

Contiene un laboratorio autocontenido que conecta ChatDev 2.0 con Codex mediante
el SDK de ChatDev, un agente deliberador nativo y un nodo Python. ChatDev se descarga como dependencia externa
en `.deps/`; sus fuentes no se incorporan al repositorio principal. Cada ejecución
crea una instantánea de código con Git independiente bajo `runs/`, conserva los
mensajes y cambios, y devuelve el resultado al grafo. El agente decide y evalúa
cada ciclo, formula la siguiente instrucción y reutiliza el mismo workspace;
las decisiones y los cambios de cada iteración se conservan. Dependencias, credenciales y
ejecuciones se ignoran en Git. Opcionalmente prepara apps Flutter aisladas y
delega su arranque/parada al gestor Android compartido, con Hot Reload entre
iteraciones, capturas del emulador propio y evaluación visual del agente. No depende de QuizAI ni de los servicios de IA. Consulta [`agent-lab/README.md`](../agent-lab/README.md).

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

Contiene procedimientos y herramientas operativas compartidas por el repositorio. La tarea `AI-APPS Development` ejecuta `start-dev-session.ps1` al iniciar sesión; este reutiliza primero el preparador Android y después el lanzador de QuizAI. `android/` registra y controla sesiones independientes mediante workers fuera del editor y reutiliza el preparador y el runner existentes. `vscode-android/` selecciona y recupera sus visores; abrir o cerrar pestañas no controla los procesos de las apps. `embedroid/` construye la distribución mantenida con transporte corregido y restauración de sesiones; `install-embedroid.ps1` instala ambos componentes. El registro y los logs quedan en `.ai-apps/android/`, fuera de Git.

### docs/

Contiene la documentación general de AI-APPS.

### .ai-apps/

Contiene datos internos utilizados durante el desarrollo, las pruebas y la experimentación.
