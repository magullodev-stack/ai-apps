# HERRAMIENTAS.md — AI-APPS

## Catálogo activo

| Herramienta | Finalidad | Ubicación | Instrucciones |
| --- | --- | --- | --- |
| QuizAI con IA | Iniciar o reutilizar el servicio Dart, conectar el emulador y ejecutar QuizAI; verificar una partida con `-VerifyOnly` y probar 1–200 generaciones P–D→Q–R de Luna sin U con `-ProbarLuna -Muestras N`; detener el servicio con `-StopService`. | [`apps/quizai/run.ps1`](../apps/quizai/run.ps1) | [`apps/quizai/README.md`](../apps/quizai/README.md) y [`ai/README.md`](../ai/README.md). |


---


## Sincronización universal de `dev`

La herramienta oficial es
[`scripts/sync-dev.ps1`](../scripts/sync-dev.ps1). No pertenece a QuizAI ni
a ningún proyecto concreto: trabaja sobre la raíz Git del repositorio y sirve
desde cualquier aplicación o subcarpeta de AI-APPS.

### Comando para pegar en PowerShell

Se puede ejecutar **desde cualquier carpeta dentro del repositorio**:

```powershell
& (Join-Path ((git rev-parse --show-toplevel).Trim()) 'scripts\sync-dev.ps1')
```

Ese bloque sí es un comando ejecutable. No hay que pegar el texto explicativo
de esta documentación en la terminal.

Desde la raíz del repositorio también sirve la forma corta:

```powershell
.\scripts\sync-dev.ps1
```

Y en VS Code puede ejecutarse sin escribir nada mediante:

`Terminal > Run Task > AI-APPS: sincronizar dev`

La tarea de [`.vscode/tasks.json`](../.vscode/tasks.json) llama exactamente
al mismo script.

### Qué sincroniza

En cada ejecución:

1. comprueba que Git esté disponible y que la rama activa sea `dev`;
2. localiza automáticamente la raíz del repositorio;
3. prepara todos los cambios locales no ignorados de cualquier proyecto;
4. incluye también todas las carpetas `.ai-apps/experimentos-*` que existan,
   sin depender del nombre de una aplicación o experimento concreto;
5. crea un commit solo cuando existen cambios;
6. consulta `origin/dev`;
7. integra el remoto mediante `rebase`;
8. publica `dev`;
9. vuelve a consultar el remoto y exige que `HEAD` y `origin/dev` sean
   idénticos;
10. si aparecen archivos nuevos mientras está sincronizando, los recoge y
    repite el ciclo.

Si el rebase encuentra un conflicto, se aborta automáticamente y no se publica
nada. Si `origin/dev` cambia durante la publicación o aparecen cambios locales
durante la operación, el procedimiento reintenta hasta tres veces.

Los archivos ignorados continúan sin publicarse, salvo las carpetas genéricas
`.ai-apps/experimentos-*`, que se incluyen explícitamente.

---

## Emulador Android compartido

`scripts/start-android.ps1` prepara el dispositivo Android de AI-APPS.

El procedimiento reutiliza un emulador conectado o inicia el AVD
Medium_Phone sin ventana externa. Durante el arranque distingue los estados
`offline` y `device`: solo consulta `sys.boot_completed` cuando ADB indica
`device`, y tolera una desconexión transitoria entre consultas. Mantiene
el límite de espera de 240 segundos y devuelve el identificador del
dispositivo preparado.

No ejecuta ninguna aplicación ni inicia servicios de inteligencia
artificial.

`scripts/vscode-android/` contiene la integración local de VS Code.

Al abrir el repositorio AI-APPS, esta integración ejecuta el procedimiento
compartido y utiliza el comando público `embedroid.openEmbedded` para
mostrar Android dentro de una pestaña del editor.

La extensión EmbeDroid debe estar instalada.

La integración local se instala en el directorio de extensiones de VS Code.
Su código fuente permanece en el repositorio.

El visor utiliza el grupo de editores activo, permitiendo alternar entre
los documentos y el teléfono mediante sus pestañas.

Para consultar los diagnósticos del arranque, abrir el panel Output de
VS Code y seleccionar `AI-APPS Android`.

El emulador es una herramienta compartida. Después de prepararlo, la
integración ejecuta el juego seleccionado en `.ai-apps/active-game.txt`.
Si el archivo contiene `none`, no ejecuta ningún juego. Cada aplicación
conserva su propio lanzador `apps/<juego>/run.ps1`.

El selector es local y no se publica en Git. Cambiarlo permite elegir
qué aplicación se ejecutará la próxima vez que se abra AI-APPS.

La tarea existente `AI-APPS: ejecutar QuizAI con IA` sigue siendo manual
y reutiliza Android cuando ya está conectado.

---

---

# GENERAR PIVOTES

.\generar-pivotes.ps1 -Ruta