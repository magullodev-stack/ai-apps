const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const file = relative => fs.readFileSync(path.join(root, relative), 'utf8');

const startup = file('scripts/start-dev-session.ps1');
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
