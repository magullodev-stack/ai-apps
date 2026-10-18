const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const file = relative => fs.readFileSync(path.join(root, relative), 'utf8');

const startup = file('scripts/start-dev-session.ps1');
// Contrato de PowerShell real: un string mal cerrado puede impedir arrancar
// la tarea antes incluso de que se escriba un mensaje en dev-session.log.
if (process.platform === 'win32') {
  const {execFileSync} = require('node:child_process');
  const parsed = [
    'scripts/start-dev-session.ps1',
    'scripts/auto-sync-dev.ps1',
    'scripts/start-ai-apps-android.ps1',
    'apps/muondia/run.ps1',
    'scripts/android/task-control.ps1',
    'scripts/android/flutter-ownership.ps1',
    'scripts/android/flutter-ownership.test.ps1',
    'scripts/android/avd-startup.test.ps1',
  ].map(relative => path.join(root, relative).replace(/'/g, "''"));
  const command = [
    '$tokens = $null; $errors = $null',
    ...parsed.map(p => [
      '$tokens = $null; $errors = $null',
      "[void][System.Management.Automation.Language.Parser]::ParseFile('" +
        p + "', [ref]$tokens, [ref]$errors)",
      'if ($errors.Count -ne 0) {',
      '  Write-Error ("PowerShell parse errors: " + $errors.Count)',
      '  exit 1',
      '}',
    ].join('\n')),
  ].join('\n');
  execFileSync('powershell.exe', [
    '-NoProfile', '-NonInteractive', '-EncodedCommand',
    Buffer.from(command, 'utf16le').toString('base64'),
  ], {timeout: 15000, windowsHide: true});
  execFileSync('powershell.exe', [
    '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
    '-File', path.join(root, 'scripts/android/avd-startup.test.ps1'),
  ], {timeout: 15000, windowsHide: true});
  execFileSync('powershell.exe', [
    '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
    '-File', path.join(root, 'scripts/android/flutter-ownership.test.ps1'),
  ], {timeout: 15000, windowsHide: true});
}
assert.equal(
  startup.split("Write-SessionLog 'Sesion Flutter terminada.'").length - 1, 1,
  'Only one persistent Flutter pipeline must exist');
assert.match(startup, /Recuperacion automatica: Hot Restart tras fallo/,
  'Recovery logging must stay in the PowerShell pipeline');

assert.match(startup, /run\.ps1'\) -Device emulator-5554 \*>\&1 \|/i,
  'Windows logon must launch Flutter, not only Dart');
assert.doesNotMatch(startup, /run\.ps1'\) -Device emulator-5554 -ServiceOnly/i,
  'The startup task must not silently downgrade to backend-only mode');
assert.match(startup, /-Action Check -Serial emulator-5554/,
  'Scheduled startup must guard against a second Flutter process');
assert.match(startup, /-Action Recover -Serial emulator-5554 -RepoRoot \$repo/,
  'Scheduled startup must recover only recognized orphaned Flutter processes');
assert.match(startup, /Flutter ajeno o no recuperable; no se toca F5/,
  'Unknown or F5 owners must still block the startup');
assert.match(startup, /while \(\$true\) \{\s*\$stage = 'Sincronizacion'/,
  'La tarea de desarrollo debe permanecer viva para reintentar tras fallos');
assert.match(startup, /Start-Sleep -Seconds \$retryDelaySeconds/,
  'Los reintentos de Flutter no deben requerir PowerShell manual');
assert.match(startup, /\[Math\]::Min\(60, \$retryDelaySeconds \* 2\)/,
  'Un fallo persistente no debe provocar bucles de arranque sin límite');
assert.doesNotMatch(startup, /exit 1\s*\}\s*$/,
  'Un Flutter fallido no debe dejar la tarea permanentemente detenida');
assert.match(startup, /Revision dev detectada/,
  'La tarea debe registrar revisiones recibidas del runner');
const runner = file('scripts/flutter-dev-runner.dart');
assert.match(runner, /final gitMonitor = Timer\.periodic/,
  'La detección de Git debe funcionar incluso sin FileSystemWatcher');
assert.match(runner, /_readGitChanges\(root, old, current, appPath\)/,
  'Evitar actualizaciones por commits no relacionados con la aplicación');
assert.match(runner, /enum FlutterChangeAction \{ none, reload, restart, rebuild \}/,
  'Clasificación única para el flujo de actualización');
assert.match(runner, /classifyFlutterChange\(event\.path, status: status\)/,
  'FileSystemWatcher debe clasificar los cambios locales');
assert.match(runner, /classifyFlutterChange\(\s*change\.path, status: change\.status/,
  'La comprobación Git debe usar la misma clasificación');
assert.match(runner, /if \(activeAction == FlutterChangeAction\.restart\) \{\s*unawaited\(controller\.restart\(\)\)/,
  'Hot Restart debe enviarse al protocolo Flutter');
assert.match(runner, /unawaited\(controller\.reload\(\)\)/,
  'Hot Reload debe enviarse al protocolo Flutter');
assert.match(runner, /if \(action == FlutterChangeAction\.rebuild\) \{\s*rebuild\(path, revision: revision\)/,
  'Cambios nativos o nuevos assets deben reconstruir la aplicación');
assert.match(runner, /onUpdateSettled = \(success, fullRestart\)/,
  'La revisión Git solo se confirma después de que Flutter responda');
assert.match(runner, /gitMonitor\.cancel\(\)/,
  'No dejar sondeos de Git vivos tras finalizar Flutter');

// Comprobar la sincronización bidireccional existente, sin añadir otro worker.
const sync = file('scripts/auto-sync-dev.ps1');
assert.match(sync, /Get-FileHash -LiteralPath \$fullPath -Algorithm SHA256/,
  'Los archivos nuevos deben participar en la comprobación de estabilidad');
assert.match(sync, /if \(\$confirmed\.Dirty -and \$confirmed\.Fingerprint -eq \$state\.Fingerprint\)/,
  'Revalidar el contenido antes de publicar un commit automático');
assert.match(sync, /Sync-Remote -WorkingDirty \$workingDirty/,
  'Consultar GitHub también con archivos locales modificados');
assert.match(sync, /if \(\$WorkingDirty\) \{[\s\S]*?waiting for clean local changes/,
  'Nunca rebasar ni publicar cambios inestables');
assert.match(sync, /'merge', '--ff-only'/,
  'Recibir cambios mediante un avance seguro, sin forzar pérdidas locales');

// Flutter y QEMU tienen fallos distintos: ADB no debe cerrar una VM sana.
const avd = file('scripts/start-ai-apps-android.ps1');
const muondia = file('apps/muondia/run.ps1');
assert.match(startup, /\$sessionErrorAction = \$ErrorActionPreference[\s\S]*?finally \{\s*\$ErrorActionPreference = \$sessionErrorAction/,
  'Advertencias de stderr nativo no deben provocar errores falsos o perder la preferencia original');
assert.match(startup, /MUONDIA_RUNNER_EXIT: \(-\?\[0-9\]\+\)/,
  'Registrar el codigo de salida del runner sin capturar secretos');
assert.match(startup, /ERROR Flutter: compilacion Gradle fallida/,
  'Distinguir errores Gradle de perdidas ADB');
assert.match(startup, /\$failureMessage -match 'Flutter terminó con un error/,
  'Clasificar RuntimeException mediante motivo Flutter sin escribir mensajes arbitrarios');
assert.match(muondia, /Write-Host "MUONDIA_RUNNER_EXIT: \$runnerExitCode"/,
  'La sesion debe comunicar solo el codigo de salida y nunca stderr completo');

assert.match(runner, /Timer\.periodic\(const Duration\(seconds: 5\)/,
  'La recuperación de una VM perdida no depende de VS Code');
assert.match(runner, /controller\.stopRequested \|\| !controller\.lostConnection\) return/,
  'Una VM Flutter conectada no debe detenerse por una consulta ADB');
assert.match(runner, /\+\+_missingChecks >= 3/,
  'Una desconexión transitoria no debe solicitar recuperar Android');
assert.match(runner, /controller\.requestDeviceRecovery\(\)/,
  'Una VM desconectada con Android ausente devuelve el control al supervisor');
assert.match(runner, /void requestDeviceRecovery\(\)/,
  'Se termina solo el Flutter propiedad del runner');
assert.match(runner, /deviceMonitor\.cancel\(\)/,
  'El detector de ADB no debe sobrevivir al proceso Flutter');
assert.match(muondia, /if \(\$runnerExitCode -eq 88\) \{[\s\S]*?ANDROID_DEVICE_LOST/,
  'La pérdida confirmada de Android sale de run.ps1 para preparar el dispositivo');
assert.doesNotMatch(muondia, /& \$adb connect \$Device/,
  'adb connect emulator-5554 no puede recuperar un AVD local');
assert.match(startup, /ANDROID_DEVICE_LOST/,
  'La tarea debe distinguir la pérdida ADB de los errores de Flutter');
assert.ok(startup.indexOf('-Action Check -Serial emulator-5554') <
  startup.indexOf("Write-SessionLog 'Preparando Android.'"),
  'Verificar Flutter propio/F5 antes de intentar reiniciar el emulador');
assert.match(avd, /muondia-f5-takeover\.txt/,
  'Un F5 con cesion explicita debe impedir el cierre del AVD');
assert.match(avd, /if \(\$flutterState -ne 'free'\)/,
  'Revalidar que F5 no ocupa el emulador justo antes de cerrarlo');
assert.match(avd, /if \(-not \$alreadyConnected -and \$existing\.Count -eq 0\)/,
  'Un proceso AVD vivo impide iniciar otra instancia aunque ADB no lo vea');
assert.match(avd, /Puerto AVD ocupado por proceso de propiedad no verificada/,
  'Un proceso ajeno que ocupe el puerto bloquea el arranque seguro');
assert.match(avd, /function Get-ManagedAvdProcesses/,
  'Recuperación de AVD identifica los procesos propios');
assert.match(avd, /qemu-system-x86_64-headless\.exe/,
  'El detector reconoce el ejecutable QEMU real de las sesiones sin ventana');
assert.match(avd, /\$current\.Name -eq 'emulator\.exe'/,
  'Solo un wrapper huerfano puede terminarse; nunca QEMU por ausencia ADB');
assert.match(avd, /-not \(Test-ManagedQemuPresent\)/,
  'Un QEMU vivo, incluidos hijos sin argumentos, protege su wrapper');
assert.doesNotMatch(avd, /taskkill\.exe[^\r\n]*\/T/,
  'Liberar un wrapper huerfano nunca debe terminar un arbol nativo');
assert.match(avd, /-avd[\s\S]*-port/,
  'La propiedad requiere nombre de AVD y puerto');
assert.match(avd, /\$current\.CreationDate -eq \$process\.CreationDate/,
  'No matar un PID reutilizado por otro proceso');
assert.match(avd, /if \(\$state -eq 'missing' -or \$state -eq 'offline'\)/,
  'Tanto la desaparición como el estado offline deben recuperarse');
assert.match(avd, /\$alreadyConnected = \$currentState -eq 'device'/,
  'offline no puede considerarse un AVD conectado');
assert.doesNotMatch(avd, /adb\s+(?:kill-server|reconnect\s+offline)/,
  'Nunca afectar globalmente otros emuladores o sesiones');

const control = file('scripts/android/task-control.ps1');
assert.match(control, /ValidateSet\('Check', 'Stop', 'Recover'\)/,
  'Recovery is an explicit action, distinct from stopping the task');
assert.match(control, /Get-MuondiaFlutterOwnership/,
  'Recovery must verify process ownership');
assert.match(control, /if \(\$Action -eq 'Stop'\) \{(?:\s|#[^\r\n]*)*Stop-ScheduledTask/,
  'Only an explicit Stop may stop the scheduled task');
assert.match(control, /\$current.CreationDate -eq \$process.CreationDate/,
  'PID reuse must not cause an unrelated process to be terminated');
assert.match(control, /if \(\$Action -eq 'Recover'\) \{ Write-Output 'recovered' \}/,
  'Recovered state must be explicit for the startup');
assert.match(file('scripts/android/flutter-ownership.ps1'),
  /Get-MuondiaFlutterOwnership/,
  'Ownership classification must remain separately testable');
assert.match(startup, /Hot reload automatico activo/,
  'The persistent startup retains its Hot Reload monitoring');

const debug = file('apps/muondia/prepare-debug.ps1');
assert.match(debug, /\$taskName = 'AI-APPS Development'/,
  'F5 must target the persistent Muondia task');
assert.match(debug, /Get-ScheduledTask -TaskName \$taskName/,
  'F5 must check the persistent task before launching');
assert.match(debug, /-Action Check -Serial emulator-5554/,
  'F5 must check the device owner');
assert.match(debug, /if \(\$task -and \$task.State -eq 'Running'\)/,
  'F5 may request explicit controlled handoff only when the task is running');
assert.match(debug, /& \$control -Action Stop/,
  'F5 releases the persistent session through its ownership guard');
assert.match(debug, /muondia-f5-takeover.txt/,
  'The F5 handoff remains explicitly marked');
assert.match(file('apps/muondia/restore-debug.ps1'),
  /-Action Check -Serial emulator-5554/,
  'F5 restores the persistent task only after the device is free');
assert.match(debug, /run\.ps1'\) -Device emulator-5554 -ServiceOnly/,
  'F5 prepares its backend only after exclusive-ownership checks');

const tasks = JSON.parse(file('.vscode/tasks.json')).tasks;
const task = tasks.find(t => t.label === 'Muondia: preparar Flutter');
assert.ok(task, 'Muondia F5 prerequisite must exist');
assert.equal(task.args.at(-1), '${workspaceFolder}\\apps\\muondia\\prepare-debug.ps1');
assert.equal(task.args.at(-2), '-File');
const launch = JSON.parse(file('.vscode/launch.json')).configurations
  .find(c => c.name === 'Muondia');
assert.ok(launch && launch.preLaunchTask === task.label,
  'Muondia F5 must use the exclusive-ownership guard');
assert.match(file('AGENTS.md'), /Invariante del entorno/,
  'The persistent-startup contract must remain explicit');
console.log('PASS: Windows arranque y recuperacion segura del Flutter propio, F5 protegido, Hot Reload conservado.');
