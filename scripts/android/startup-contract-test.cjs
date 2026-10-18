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
    'scripts/android/task-control.ps1',
    'scripts/android/flutter-ownership.ps1',
    'scripts/android/flutter-ownership.test.ps1',
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
assert.match(runner, /_readGitChanges\(root, previous, next, appPath\)/,
  'Evitar actualizaciones por commits no relacionados con la aplicación');
assert.match(runner, /forceRestart: true/,
  'Los commits relevantes deben reconstruir la aplicación Flutter');
assert.match(runner, /gitMonitor\.cancel\(\)/,
  'No dejar sondeos de Git vivos tras finalizar Flutter');

const control = file('scripts/android/task-control.ps1');
assert.match(control, /ValidateSet\('Check', 'Stop', 'Recover'\)/,
  'Recovery is an explicit action, distinct from stopping the task');
assert.match(control, /Get-MuondiaFlutterOwnership/,
  'Recovery must verify process ownership');
assert.match(control, /if \(\$Action -eq 'Stop'\) \{\s*Stop-ScheduledTask/,
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
assert.match(debug, /Get-ScheduledTask -TaskName 'AI-APPS Development'/,
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
