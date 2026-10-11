# agent-lab — ChatDev 2.0 → Codex

Laboratorio independiente: un agente real de ChatDev recibe una instrucción,
decide qué construir, delega en Codex y evalúa sus resultados. Formula la siguiente
instrucción y vuelve a ejecutarla sobre el mismo código aislado, sin intervención
humana. El laboratorio no forma parte de la infraestructura `ai/` ni arranca
QuizAI, Flutter, Android o servicios del repositorio.

El modo directo original conserva el SDK de ChatDev como orquestador determinista:
`instruction` → `delegate` → `codex` → `result`. No necesita una clave de
modelo para ChatDev ni otro modelo planificador. Codex realiza la modificación.
El nodo Python ejecuta únicamente el puente fijo del laboratorio; la instrucción
se conserva como datos en `request.json` y se entrega a Codex por stdin.

Desde PowerShell, en la raíz de AI-APPS:

```powershell
.\agent-lab\install.ps1
.\agent-lab\test.ps1
.\agent-lab\deliberate.ps1 -Offline -Instruction 'Construye un contador entero con pruebas'
.\agent-lab\deliberate.ps1 -Instruction 'Construye una pequeña utilidad de enteros y decide sus mejoras'
.\agent-lab\run.ps1 -Offline -Instruction 'Corrige increment para que sume uno'
.\agent-lab\run.ps1 -Instruction 'Corrige increment para que sume uno y ejecuta sus pruebas'
```

`install.ps1` descarga uv portátil con SHA-256 verificado, Python 3.12.13 y
[ChatDev 2.0 oficial](https://github.com/OpenBMB/ChatDev/tree/v2.0.0) en
`.deps/chatdev`. Comprueba la revisión
`f0db945ed39be33599fbc700a7e60cdb68d1df2d` y utiliza su `uv.lock` con
`uv sync --frozen`. `.venv`, `.python`, `.tools` y `.cache` pertenecen al
laboratorio. Se necesita Git y acceso a GitHub/PyPI para instalar; después las
pruebas offline no usan la red. No se registran tareas de Windows ni servicios.

Las fuentes de ChatDev permanecen como dependencia descargada e ignorada: no
son un submódulo ni código incorporado a AI-APPS. El instalador puede repetirse;
rechaza revisiones incorrectas o modificaciones de la dependencia.

La ejecución real requiere un `codex.exe` nativo en PATH, por ejemplo el de la
extensión instalada, o una ruta explícita con `-CodexPath`. Reutiliza el login
del CLI; si falta, ejecuta `codex login` desde tu terminal. No copia ni imprime
`auth.json`. También admite `CODEX_API_KEY` proporcionada al proceso, sin
guardarla en los archivos de configuración. Las credenciales de los servicios
de AI-APPS y `API_KEY` de ChatDev no se entregan al ejecutor.

El modo autónomo usa `workflows/deliberate.yaml`: un nodo nativo `type: agent`
de ChatDev, con el proveedor registrado `lab_codex`. Este proveedor conecta su
conversación al modelo de Codex mediante el CLI en sandbox `read-only` y exige
una decisión JSON validada contra `prompts/decision.schema.json`. El diseño y
las instrucciones proceden del modelo; el controlador Python solo valida,
limita iteraciones y vuelve a llamar al puente existente. El planificador recibe
la instrucción inicial, decisiones anteriores, resultados, patches y archivos
actuales del workspace. El contexto tiene límites de tamaño explícitos y registra
qué contenido fue omitido. No dispone de herramientas de edición.

`config/deliberation.json` configura proveedor, modelo del planificador, timeout
y máximo de iteraciones (2 por defecto, entre 2 y 10). `-Config` permite usar otro
archivo con esos cuatro campos; rechaza campos adicionales, incluidas credenciales.
`-Model` selecciona únicamente el modelo ejecutor y `-TimeoutSeconds` limita cada
ejecución de código. Ambos procesos usan por defecto el login existente de Codex.
Para una autenticación independiente del planificador, se pueden proporcionar
`AGENT_LAB_PLANNER_CODEX_HOME` o `AGENT_LAB_PLANNER_CODEX_API_KEY` en el entorno.
Se aplican solo al proceso del planificador, no se reenvían al ejecutor ni se
guardan como configuración. No se toman credenciales de los servicios de AI-APPS.

Cada resultado vuelve al agente, incluida la última iteración. Su evaluación
decide continuar con una nueva instrucción o terminar. Solo se marca `completed`
cuando el agente acepta el resultado y hay al menos dos iteraciones consecutivas
con cambios nuevos y ejecución completada. Un cierre antes de ese mínimo queda
como `stopped_early`; agotar el presupuesto sin aceptación queda como
`iteration_limit`. Fallos, timeouts y ausencia de cambios nuevos se entregan al
agente para revisión. Un JSON inválido detiene el controlador con `failed`.
La aceptación del modelo es una evaluación conservada, no una garantía de
corrección; las pruebas que ejecuta Codex quedan en sus eventos y respuesta.

`-Offline` conserva el nodo nativo y sustituye su proveedor y el proceso ejecutor
por dobles deterministas locales. No llama a modelos ni necesita credenciales.

```powershell
.\agent-lab\run.ps1 -CodexPath 'C:\ruta\codex.exe' `
  -Instruction 'Corrige el error y ejecuta las pruebas locales' -TimeoutSeconds 300
```

El puente usa [Codex no interactivo](https://developers.openai.com/codex/noninteractive)
con `--json`, `--output-last-message`, `--ephemeral`, `workspace-write` y
`approval_policy="never"`. Omite configuración, reglas y conectores personales
con `--ignore-user-config` y `--ignore-rules`. En Windows selecciona
`windows.sandbox="unelevated"` solo para ese proceso, sin aprovisionar cuentas
ni modificar la configuración global. La [documentación del sandbox de Windows](https://developers.openai.com/codex/windows)
explica las limitaciones de aislamiento de red de esta implementación.
No utiliza flags de acceso completo. `-Model` permite elegir explícitamente
un modelo; si se omite se utiliza el predeterminado del CLI sin cargar la
configuración personal. Requiere un CLI que admita estos flags; validado con
`0.162.0-alpha.17.2`.

Para trabajar sobre otro proyecto Git:

```powershell
.\agent-lab\run.ps1 -SourceRepo 'C:\ruta\proyecto' `
  -Instruction 'Implementa la corrección y ejecuta sus pruebas locales'
```

`deliberate.ps1` admite también `-SourceRepo` y `-CodexPath`.

Se exporta su `HEAD` con `git archive` y se crea un repositorio independiente
dentro de la ejecución, sin remoto, ramas compartidas, worktree ni alternates.
Los cambios sin commit del proyecto de origen no se copian. Se rechazan enlaces
y archivos especiales del archivo de entrada. El `AGENTS.md` de la copia se
sustituye por instrucciones de aislamiento; el original permanece intacto.
Cada ejecución parte de una nueva instantánea y no aplica sus cambios a `dev`.
`-SourceRepo` no prepara las dependencias del proyecto exportado. Empieza por
el ejemplo incluido, que no necesita dependencias adicionales.

Al terminar, el comando imprime la carpeta `runs/session_<fecha>_<id>` y el
estado. Dentro se conservan:

| Archivo | Contenido |
| --- | --- |
| `manifest.json` | Estado, fechas UTC, versión de ChatDev, origen y commit inicial. |
| `request.json`, `codex-prompt.txt` | Instrucción original y prompt enviado. |
| `exchange.jsonl` | Entrega ChatDev → Codex y respuesta Codex → ChatDev. |
| `command.json` | Argumentos del ejecutor, sin credenciales. |
| `codex-events.jsonl`, `codex-stderr.txt`, `codex-final.txt` | Eventos, diagnóstico y respuesta final de Codex. |
| `response.json`, `chatdev-result.txt` | Respuesta del puente y mensaje final recibido por ChatDev, comprobados iguales. |
| `chatdev/`, `chatdev.log`, `WareHouse/` | Salidas de nodos, contexto y registros del workflow original. |
| `workspace/` | Código resultante y su repositorio Git independiente. |
| `changes.patch`, `changes.txt`, `changes.json`, `git-status.txt` | Diff binario contra la instantánea inicial, archivos afectados y hash del patch. |

La captura usa un índice auxiliar: incluye archivos nuevos, borrados y binarios
sin alterar el índice de trabajo. También conserva cambios si un ejecutor
llega a crear un commit dentro de su copia. Las ejecuciones fallidas y parciales
se mantienen para diagnóstico. Los estados son `completed`, `failed`,
`timed_out` y `no_changes`; solo `completed` devuelve código de salida 0.
Una respuesta sin cambios no acredita el ciclo de modificación solicitado.
`completed` acredita intercambio, final de turno y cambios; no sustituye la
revisión de código ni garantiza que las pruebas elegidas por el modelo pasen.
Un timeout termina exclusivamente el árbol de procesos del ejecutor de esa
ejecución y devuelve su resultado a ChatDev.

El modo autónomo imprime `runs/session_auto_<fecha>_<id>` y conserva además:

| Archivo o carpeta | Contenido |
| --- | --- |
| `decisions.jsonl`, `final-decision.json` | Decisiones inicial, intermedias y final, con instrucciones y evaluaciones. |
| `decisions/000/`, `001/`, … | Entrada del agente, conversación del proveedor, respuesta JSON, eventos del modelo y salidas del nodo nativo de ChatDev. |
| `cycles/001/`, `002/`, … | Decisión, instrucción delegada, intercambio, resultados del puente, evaluación y registros de ChatDev de cada ciclo. |
| `cycles/<n>/changes.patch`, `changes.json` | Cambios respecto al final del ciclo anterior, incluso si hubo fallo; árbol Git y hash del patch. |
| `cycles/<n>/workspace.tar` | Instantánea completa de archivos capturados al terminar ese ciclo. |
| `workspace/` | Un único repositorio aislado reutilizado por todas las iteraciones. |
| `manifest.json`, `changes.patch` | Estado y relación de iteraciones, y cambios acumulados respecto al inicio. |

La evaluación de `cycles/001/evaluation.json` contiene exactamente la instrucción
delegada en `cycles/002/request.json`. La última evaluación también se conserva.
Los patches pueden aplicarse consecutivamente a una copia de la instantánea
inicial; los archivos `workspace.tar` permiten inspeccionar cada resultado sin
sobrescribir el workspace final. Las decisiones conservan un resumen de diseño
y evidencia de evaluación, sin solicitar razonamiento interno del modelo.

Las pruebas usan ChatDev instalado y un doble de proceso de Codex, sin modelos:
intercambio completo, Unicode, instrucciones tratadas como datos, patch aplicable
con archivos nuevos y binarios, protección del origen, fallo, timeout y respuesta
incompleta. Los archivos de prueba quedan en `runs/` para inspección.

La suite contiene 18 pruebas offline, incluidas dos iteraciones sobre el mismo
workspace, evaluación final, instrucciones posteriores derivadas del resultado,
patches aplicables consecutivamente, salidas inválidas, cierre prematuro y límites
ante fallos, timeout o ausencia de cambios nuevos. También se validó una ejecución
real de dos iteraciones: el agente decidió corregir y validar `increment`, revisó
el resultado y delegó añadir `step` y `decrement`; aceptó el segundo resultado,
cuyas diez pruebas locales pasan. Sus registros permanecen en `runs/` ignorado.

ChatDev v2.0.0 prepara `env` en `PythonNodeExecutor._run_process`, pero omite
`env=env` al llamar a `subprocess.run`. El workflow evita depender de ese campo:
introduce solo las rutas internas mediante literales JSON y selecciona el
intérprete explícitamente. No modifica las fuentes descargadas.

Dependencias, credenciales y ejecuciones están excluidas con `.gitignore` local.
Los registros pueden contener código e instrucciones del usuario; permanecen
locales y nunca se añaden al commit del laboratorio. El proceso real de Codex
puede mantener su caché de autenticación propia fuera de `agent-lab`.

Para retirar la instalación, termina primero sus ejecuciones:

```powershell
# Retirar dependencias; conservar resultados y credenciales locales.
.\agent-lab\uninstall.ps1
# Retirar también resultados y secretos locales del laboratorio.
.\agent-lab\uninstall.ps1 -PurgeRuns -PurgeSecrets
# Eliminar completamente agent-lab, incluidos sus archivos versionados.
.\agent-lab\uninstall.ps1 -RemoveLab -PurgeRuns -PurgeSecrets
```

Admite `-WhatIf`. Comprueba las rutas absolutas antes de borrar, rechaza raíces
enlazadas y ejecuciones con estado `started`. No desinstala Codex, modifica refs
Git ni elimina la autenticación del CLI externo. La eliminación de archivos
versionados se reflejará como cambios locales de Git; el script no hace commit
ni push.
