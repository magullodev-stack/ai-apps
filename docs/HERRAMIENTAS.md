# HERRAMIENTAS.md — AI-APPS

## Catálogo activo

| Herramienta | Finalidad | Ubicación | Instrucciones |
| --- | --- | --- | --- |
| QuizAI con IA | Iniciar o reutilizar el servicio Dart, conectar el emulador y ejecutar QuizAI; verificar una partida con `-VerifyOnly` y probar 1–200 generaciones P–D→Q–R de Luna sin U con `-ProbarLuna -Muestras N`; detener el servicio con `-StopService`. | [`apps/quizai/run.ps1`](../apps/quizai/run.ps1) | [`apps/quizai/README.md`](../apps/quizai/README.md) y [`ai/README.md`](../ai/README.md). |


---


## Sincronización de `dev` al abrir VS Code

La tarea `AI-APPS: sincronizar dev al abrir VS Code` en
[`.vscode/tasks.json`](../.vscode/tasks.json) ejecuta
[`scripts/sync-dev.ps1`](../scripts/sync-dev.ps1) al abrir la carpeta del proyecto.
VS Code puede solicitar **una vez** autorización para permitir tareas automáticas
(Allow Automatic Tasks); mientras no se autoricen, la sincronización no se ejecuta.
La salida aparece en la terminal de la tarea.

El procedimiento consulta `origin/dev` mediante `git fetch` y comprueba la
rama y el estado local. Si `dev` está limpio y es antecesor de `origin/dev`,
ejecuta exclusivamente `git merge --ff-only origin/dev` y verifica que el
`HEAD` resultante coincida con el remoto. Si ya coincide, informa de ello.
Si existen cambios sin confirmar, otra rama activa, commits locales no publicados
o historias divergentes, informa y **no modifica nada**. Tampoco ejecuta
`reset --hard`, `rebase`, `push` ni modifica archivos ignorados como
`.ai-apps/openai-key.dpapi`.

La tarea solo se ejecuta cuando VS Code abre el proyecto; **no** sincroniza
continuamente ni se activa mientras el editor permanece abierto. Una rama local
ya divergente exige intervención manual y respaldo previo; nunca se resuelve
automáticamente.

---

## Emulador Android compartido

`scripts/start-android.ps1` prepara el dispositivo Android de AI-APPS.

El procedimiento reutiliza un emulador conectado o inicia el AVD
Medium_Phone sin ventana externa. Espera a que Android termine de
arrancar y devuelve el identificador del dispositivo preparado.

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

## COMMIT

$ErrorActionPreference = 'Stop'
>> $PSNativeCommandUseErrorActionPreference = $false
>> 
>> Set-Location 'C:\Users\Miquelet\repos\ai-apps'
>> 
>> # 1. Verificar rama y ausencia de conflictos pendientes
>> if ((git branch --show-current) -ne 'dev') {
>>     throw 'La rama activa no es dev.'
>> }
>> 
>> if (@(git ls-files -u).Count -gt 0) {
>>     throw 'Hay conflictos pendientes. Resuélvelos antes de sincronizar.'
>> }
>> 
>> # 2. Guardar TODOS los cambios habituales
>> git add -A
>> if ($LASTEXITCODE -ne 0) { throw 'Error en git add.' }
>> 
>> # Incluir TODOS los resultados experimentales, actuales y futuros
>> $experimentos = '.ai-apps/experimentos-luna-pd'
>> 
>> if (Test-Path -LiteralPath $experimentos -PathType Container) {
>>     git add -f -A -- $experimentos
>>     if ($LASTEXITCODE -ne 0) {
>>         throw 'Error al añadir los experimentos.'
>>     }
>> }
>> 
>> git diff --cached --check
>> if ($LASTEXITCODE -ne 0) {
>>     throw 'Hay errores en los cambios preparados.'
>> }
>> 
>> # 3. Crear commit solo si hay cambios
>> $pendientes = @(git diff --cached --name-only)
>> 
>> if ($LASTEXITCODE -ne 0) {
>>     throw 'No se pudieron comprobar los cambios.'
>> }
>> 
>> if ($pendientes.Count -gt 0) {
>>     git commit -m "Sincronizar AI-APPS"
>>     if ($LASTEXITCODE -ne 0) {
>>         throw 'No se pudo crear el commit.'
>>     }
>> }
>> 
>> # 4. Crear respaldo local
>> $respaldo = 'respaldo-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff')
>> 
>> git branch $respaldo
>> if ($LASTEXITCODE -ne 0) {
>>     throw 'No se pudo crear el respaldo.'
>> }
>> 
>> # 5. Descargar cambios de GitHub
>> git fetch origin dev
>> if ($LASTEXITCODE -ne 0) {
>>     throw 'No se pudieron descargar los cambios.'
>> }
>> 
>> # 6. Integrar ambas versiones sin descartar cambios locales
>> git merge --no-edit origin/dev
>> 
>> if ($LASTEXITCODE -ne 0) {
>>     throw "Conflicto de integración. Respaldo: $respaldo. No se ha publicado nada."
>> }
>> 
>> # 7. Publicar en GitHub
>> git push origin dev
>> if ($LASTEXITCODE -ne 0) {
>>     throw 'No se pudo publicar en GitHub.'
>> }
>> 
>> # 8. Comprobar que GitHub y VS Code coinciden
>> git fetch origin dev
>> if ($LASTEXITCODE -ne 0) {
>>     throw 'No se pudo verificar GitHub.'
>> }
>> 
>> $localSha  = git rev-parse HEAD
>> $remoteSha = git rev-parse origin/dev
>> 
>> if ($localSha -ne $remoteSha) {
>>     throw 'La sincronización no se ha completado.'
>> }
>> 
>> Write-Host ''
>> Write-Host 'SINCRONIZACION COMPLETADA' -ForegroundColor Green
>> Write-Host "VS Code: $localSha"
>> Write-Host "GitHub:  $remoteSha"
>> Write-Host "Respaldo: $respaldo"
>> Write-Host ''

---

# GENERAR PIVOTES

.\generar-pivotes.ps1 -Ruta