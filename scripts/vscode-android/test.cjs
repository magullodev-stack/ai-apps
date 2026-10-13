const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../../.ai-apps/editor-tests');
fs.mkdirSync(path.join(root, 'scripts'), { recursive: true });
fs.writeFileSync(path.join(root, 'AGENTS.md'), 'Test');
fs.writeFileSync(path.join(root, 'scripts/start-dev-session.ps1'), 'Test');
const commands = new Map(), panels = new Map(), calls = [], intervals = [];
let treeProvider, taskRunning = true;
let entries = [
  { appId: 'muondia', label: 'Muondia', serial: 'emulator-5554', id: 'muondia@emulator-5554', kind: 'development-task', active: true, deviceReady: true, status: 'running', epoch: '1:100' },
  { appId: 'lab', label: 'Lab', serial: 'emulator-5556', id: 'lab@emulator-5556', kind: 'flutter', active: true, deviceReady: true, status: 'running', epoch: '2:200' }
];
class Sessions {
  async list() { return entries; }
  find(id) { return entries.find(item => item.id === id); }
  async start(id) { calls.push(['start', id]); }
  async stop(id) { calls.push(['stop', id]); }
}
const viewer = { async openSession(session, reconnect) {
  calls.push(['open', session.id, !!reconnect]); panels.set(session.id, session);
}, listSessions: () => [...panels.values()] };
const disposable = () => ({ dispose() {} });
const vscode = {
  workspace: { isTrusted: true, workspaceFolders: [{ uri: { fsPath: root } }],
    getConfiguration: () => ({ update: async () => {} }) },
  ConfigurationTarget: { Workspace: 2 }, StatusBarAlignment: { Left: 1 },
  TreeItem: class { constructor(label) { this.label = label; } }, ThemeIcon: class {},
  EventEmitter: class { constructor() { this.event = () => {}; } fire() {} dispose() {} },
  extensions: { getExtension: () => ({ activate: async () => viewer }) },
  commands: { registerCommand: (name, callback) => { commands.set(name, callback); return disposable(); } },
  window: { createOutputChannel: () => ({ ...disposable(), appendLine() {} }),
    showErrorMessage: message => { throw new Error(message); },
    createTreeView: (_, options) => { treeProvider = options.treeDataProvider; return disposable(); },
    createStatusBarItem: () => ({ ...disposable(), show() {} }),
    showQuickPick: async (choices, options) => options.canPickMany ? choices : choices[0] }
};
const sandbox = { module: { exports: {} }, setInterval: fn => { intervals.push(fn); return 1; }, clearInterval() {},
  require(name) {
    if (name === 'vscode') return vscode;
    if (name.replace(/\\/g, '/').endsWith('android/sessions.cjs')) return { Sessions };
    if (name.replace(/\\/g, '/').endsWith('android/windows.cjs')) return {
      Windows: class { async taskRunning() { return taskRunning; } }
    };
    return require(name);
  } };
vm.runInNewContext(fs.readFileSync(path.join(__dirname, 'extension.js'), 'utf8'), sandbox);
async function run() {
  const context = { subscriptions: [] };
  const api = await sandbox.module.exports.activate(context);
  assert.equal(panels.size, 1, 'Startup restores Muondia without reopening transient experiments');
  assert.equal(panels.has('muondia@emulator-5554'), true);
  assert.equal(panels.has('lab@emulator-5556'), false);
  assert.equal(treeProvider.getTreeItem({ ...entries[1], active: false, status: 'starting' }).contextValue,
    'androidRunning', 'A starting session exposes Stop instead of a second Start');
  assert.equal(calls.some(call => call[0] !== 'open'), false,
    'A running development task is never started twice');
  await api.refresh();
  assert.equal(calls.length, 1, 'Polling does not duplicate Muondia or revive a transient experiment');
  await api.refresh();
  assert.equal(panels.size, 1, 'Transient applications stay closed until explicitly selected');
  await commands.get('aiAppsAndroid.select')();
  assert.equal(panels.size, 2, 'Multi-selection reopens without closing the other app');
  await commands.get('aiAppsAndroid.open')();
  assert.deepEqual(calls.at(-1), ['open', 'muondia@emulator-5554', false], 'Command palette opens a single picked session');
  await commands.get('aiAppsAndroid.reconnect')(entries[1]);
  assert.deepEqual(calls.at(-1), ['open', 'lab@emulator-5556', true]);
  entries[1].deviceReady = false; entries[1].active = false;
  await api.refresh();
  entries[1].deviceReady = true; entries[1].active = true;
  await api.refresh();
  assert.deepEqual(calls.at(-1), ['open', 'lab@emulator-5556', true], 'ADB disconnect/reconnect recovers only its existing panel');
  await commands.get('aiAppsAndroid.stop')(entries[1]);
  assert.ok(calls.some(call => call[0] === 'stop' && call[1] === entries[1].id));
  assert.equal(calls.some(call => call[0] === 'stop' && call[1] === entries[0].id), false);
  // Un paquete Android antiguo puede seguir en primer plano aunque Flutter
  // y la tarea ya hayan terminado: debe recuperarse la tarea, no el APK.
  taskRunning = false;
  await sandbox.module.exports.activate({ subscriptions: [] });
  assert.deepEqual(calls.filter(call => call[0] === 'start'),
    [['start', 'muondia@emulator-5554']],
    'VS Code reopens the stopped Flutter development task even with a stale Android PID');
  assert.equal(panels.size, 2, 'Reactivation recovers active sessions without tab growth');
  entries = Array.from({ length: 150 }, (_, i) => ({ ...entries[1], id: `app-${i}@device-${i}`, appId: `app-${i}`,
    serial: `device-${i}`, label: `App ${i}`, epoch: String(i) }));
  await api.refresh();
  assert.equal(panels.size, 152, 'No fixed maximum of tabs; existing tabs untouched');
  vscode.workspace.isTrusted = false;
  assert.equal(await sandbox.module.exports.activate({ subscriptions: [] }), undefined);
  console.log('PASS: startup task recovery without duplicate Flutter or stale APK relaunch, multi-selector, polling/close separation, target reconnect/stop, reactivation, 150 sessions and workspace trust.');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
