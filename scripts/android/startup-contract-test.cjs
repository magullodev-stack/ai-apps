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
  const startupPath = path.join(root, 'scripts/start-dev-session.ps1')
    .replace(/'/g, "''");
  const command = [
    '$tokens = $null; $errors = $null',
    "[void][System.Management.Automation.Language.Parser]::ParseFile('" +
      startupPath + "', [ref]$tokens, [ref]$errors)",
    'if ($errors.Count -ne 0) {',
    '  Write-Error ("PowerShell startup parse errors: " + $errors.Count)',
    '  exit 1',
    '}',
  ].join('\n');
  execFileSync('powershell.exe', [
    '-NoProfile', '-NonInteractive', '-EncodedCommand',
    Buffer.from(command, 'utf16le').toString('base64'),
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
assert.match(startup, /Hot reload automatico activo/,
  'The persistent startup retains its Hot Reload monitoring');

const debug = file('apps/muondia/prepare-debug.ps1');
assert.match(debug, /Get-ScheduledTask -TaskName 'AI-APPS Development'/,
  'F5 must check the persistent task before launching');
assert.match(debug, /-Action Check -Serial emulator-5554/,
  'F5 must check the device owner');
assert.doesNotMatch(debug, /Stop-ScheduledTask|-Action Stop/,
  'F5 must never stop the persistent session implicitly');
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
console.log('PASS: Windows logon owns Muondia Flutter; F5 cannot stop it; Hot Reload is preserved.');
