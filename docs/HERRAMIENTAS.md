# HERRAMIENTAS.md — AI-APPS

## Catálogo activo

| Herramienta | Finalidad | Ubicación | Instrucciones |
| --- | --- | --- | --- |
| QuizAI con IA | Iniciar o reutilizar el servicio Dart, conectar el emulador y ejecutar QuizAI; verificar una partida con `-VerifyOnly` y probar 1–200 generaciones P–D→Q–R de Luna sin U con `-ProbarLuna -Muestras N`; detener el servicio con `-StopService`. | [`apps/quizai/run.ps1`](../apps/quizai/run.ps1) | [`apps/quizai/README.md`](../apps/quizai/README.md) y [`ai/README.md`](../ai/README.md). |


---


## Sincronización de `dev`

La tarea manual `AI-APPS: sincronizar dev` en
[`.vscode/tasks.json`](../.vscode/tasks.json) ejecuta
[`scripts/sync-dev.ps1`](../scripts/sync-dev.ps1).

Es la única operación de sincronización bidireccional entre la copia local
de VS Code y `origin/dev`:

1. comprueba que la rama activa sea `dev`;
2. prepara todos los cambios locales no ignorados;
3. incluye explícitamente `.ai-apps/experimentos-luna-pd` cuando existe;
4. crea un commit local solo si hay cambios;
5. consulta `origin/dev`;
6. integra los cambios remotos mediante `rebase`;
7. publica `dev`;
8. vuelve a consultar el remoto y verifica que `HEAD` y `origin/dev`
   sean idénticos.

Si el rebase encuentra un conflicto, se aborta automáticamente y no se publica
nada. Si el remoto cambia durante la publicación, el procedimiento reintenta
hasta tres veces. Los archivos ignorados siguen sin publicarse salvo la carpeta
de experimentos indicada expresamente.

La tarea ya no se ejecuta automáticamente al abrir VS Code: sincronizar implica
crear commits y publicar cambios, por lo que se ejecuta de forma explícita desde
`Terminal > Run Task > AI-APPS: sincronizar dev`.

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