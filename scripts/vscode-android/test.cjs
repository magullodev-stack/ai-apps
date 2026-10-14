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
  { appId: 'muondia', label: 'Muondia', serial: 'emulator-5554', id: 'muondia@emulator-5554', kind: 'development-task', active: true, deviceReady: true, status: 'running', epoch: '1:100',
    projectPath: path.resolve(__dirname, '../../apps/muondia'), packageName: 'com.aiapps.muondia' }
];
class Sessions {
  constructor(_root, platform) { this.platform = platform; }
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
  TreeItemCollapsibleState: { None: 0, Collapsed: 1, Expanded: 2 },
  TreeItem: class { constructor(label) { this.label = label; } }, ThemeIcon: class {},
  EventEmitter: class {
    constructor() {
      this.listeners = [];
      this.event = callback => {
        this.listeners.push(callback);
        return disposable();
      };
    }
    fire() { for (const callback of this.listeners) callback(); }
    dispose() { this.listeners = []; }
  },
  extensions: { getExtension: () => ({ activate: async () => viewer }) },
  commands: { registerCommand: (name, callback) => { commands.set(name, callback); return disposable(); } },
  window: { createOutputChannel: () => ({ ...disposable(), appendLine() {} }),
    showErrorMessage: message => { throw new Error(message); },
    createTreeView: (id, options) => {
      if (id === 'aiAppsAndroid.sessions') treeProvider = options.treeDataProvider;
      return disposable();
    },
    createStatusBarItem: () => ({ ...disposable(), show() {} }),
    showQuickPick: async (choices, options) => options.canPickMany ? choices : choices[0] }
};
const sandbox = { module: { exports: {} }, setInterval: fn => { intervals.push(fn); return 1; }, clearInterval() {},
  require(name) {
    if (name === 'vscode') return vscode;
    if (name.replace(/\\/g, '/').endsWith('android/sessions.cjs')) return { Sessions };
    if (name.replace(/\\/g, '/').endsWith('android/windows.cjs')) return {
      Windows: class {
        constructor() { this.adb = 'adb.exe'; }
        async taskRunning() { return taskRunning; }
        async appPid() { return '2345'; }
        async run(file, args) { calls.push(['adb', file, ...args]); return ''; }
      }
    };
    return require(name);
  } };
vm.runInNewContext(fs.readFileSync(path.join(__dirname, 'extension.js'), 'utf8'), sandbox);
async function run() {
  const context = { subscriptions: [] };
  const api = await sandbox.module.exports.activate(context);
  assert.equal(panels.size, 1, 'Startup restores only the registered Muondia session');
  assert.equal(panels.has('muondia@emulator-5554'), true);
  assert.equal(treeProvider.getTreeItem({ ...entries[0], active: false, status: 'starting' }).contextValue,
    'androidRunning', 'A starting session exposes Stop instead of a second Start');
  assert.equal(calls.some(call => call[0] !== 'open'), false,
    'A running development task is never started twice');
  const roots = treeProvider.getChildren();
  const explorerRoot = roots.find(entry => entry.experienceExplorerRoot);
  assert.ok(explorerRoot, 'The explorer is embedded in the existing Android view');
  assert.equal(treeProvider.getTreeItem(explorerRoot).label, 'Explorador de experiencias');
  // Las sesiones de laboratorio pueden seguir registradas sin tapar
  // las herramientas de Muondia: se agrupan, nunca se eliminan.
  entries = [
    entries[0],
    ...Array.from({ length: 6 }, (_, index) => ({
      appId: `lab-${index}`,
      label: `Lab ${index}`,
      serial: `emulator-${5556 + (2 * index)}`,
      id: `lab-${index}@emulator-${5556 + (2 * index)}`,
      kind: 'flutter',
      active: false,
      deviceReady: false,
      status: index === 0 ? 'offline' : 'failed',
      epoch: '',
    })),
  ];
  await api.refresh();
  const compactRoots = treeProvider.getChildren();
  assert.equal(compactRoots.length, 3, 'Muondia, explorer and one optional group');
  assert.equal(compactRoots[0].id, 'muondia@emulator-5554',
    'The persistent Muondia session remains visible');
  assert.equal(compactRoots[1], explorerRoot, 'Experiences stay directly accessible');
  const inactiveGroup = compactRoots[2];
  assert.equal(treeProvider.getTreeItem(inactiveGroup).label, 'Otras sesiones (6)');
  assert.equal(treeProvider.getTreeItem(inactiveGroup).collapsibleState,
    vscode.TreeItemCollapsibleState.Collapsed,
    'Inactive sessions are collapsed by default');
  assert.equal(treeProvider.getChildren(inactiveGroup).length, 6,
    'All registered sessions remain available for management');
  entries = entries.slice(0, 1);
  await api.refresh();
  assert.deepEqual(Array.from(treeProvider.getChildren(), item =>
    item === explorerRoot ? 'explorer' : item.id),
    ['muondia@emulator-5554', 'explorer'],
    'No empty inactive group is shown');
  let invalidations = 0;
  treeProvider.onDidChangeTreeData(() => invalidations++);
  await api.refresh();
  await api.refresh();
  assert.equal(invalidations, 0,
    'Polling without session/catalog changes must not redraw expanded nodes');
  const apps = treeProvider.getChildren(explorerRoot);
  assert.equal(apps.length, 1, 'Muondia catalog is detected');
  const groups = treeProvider.getChildren(apps[0]);
  assert.deepEqual(Array.from(groups, group => group.experienceExplorerNode.label),
    ['Acceso', 'Primera experiencia', 'Aplicación']);
  const firstExperience = treeProvider.getChildren(groups[1])[0];
  const states = treeProvider.getChildren(firstExperience);
  assert.deepEqual(Array.from(states, state => state.experienceExplorerNode.state.id),
    ['inicio', 'progreso', 'final']);
  const preview = treeProvider.getTreeItem(states[1]).command;
  await commands.get(preview.command)(...preview.arguments);
  assert.deepEqual(calls.at(-1), [
    'adb', 'adb.exe', '-s', 'emulator-5554', 'shell', 'am', 'start',
    '-n', 'com.aiapps.muondia/.MainActivity',
    '-a', 'com.aiapps.muondia.DEV_OPEN_EXPERIENCE', '-f', '0x20000000',
    '--es', 'experience', 'loading', '--es', 'state', 'progreso'
  ], 'Clicking a tree state changes the running emulator without Flutter restart');
  calls.pop();
  await commands.get('aiAppsAndroid.auth')();
  assert.deepEqual(calls.at(-1), [
    'adb', 'adb.exe', '-s', 'emulator-5554', 'shell', 'am', 'start',
    '-n', 'com.aiapps.muondia/.MainActivity',
    '-a', 'com.aiapps.muondia.DEV_SHOW_AUTH', '-f', '0x20000000',
  ], 'F7 invokes Muondia development activity without keyboard or Flutter restart');
  calls.pop();
  await api.refresh();
  assert.equal(invalidations, 0,
    'Preview and routine polling must preserve the expanded tree');
  assert.equal(calls.length, 1, 'Polling does not duplicate Muondia');
  panels.delete('muondia@emulator-5554');
  await api.refresh();
  assert.equal(panels.size, 0, 'Manually closed panel stays closed while its session is unchanged');
  await commands.get('aiAppsAndroid.select')();
  assert.equal(panels.size, 1, 'Explicit selection reopens the Muondia viewer');
  await commands.get('aiAppsAndroid.open')();
  assert.deepEqual(calls.at(-1), ['open', 'muondia@emulator-5554', false], 'Command palette opens a single picked session');
  await commands.get('aiAppsAndroid.reconnect')(entries[0]);
  assert.deepEqual(calls.at(-1), ['open', 'muondia@emulator-5554', true]);
  entries[0].deviceReady = false; entries[0].active = false;
  await api.refresh();
  entries[0].deviceReady = true; entries[0].active = true;
  await api.refresh();
  assert.deepEqual(calls.at(-1), ['open', 'muondia@emulator-5554', true],
    'ADB disconnect/reconnect recovers the existing Muondia panel');
  await commands.get('aiAppsAndroid.stop')(entries[0]);
  assert.ok(calls.some(call => call[0] === 'stop' && call[1] === entries[0].id));
  // Un paquete Android antiguo puede seguir en primer plano aunque Flutter
  // y la tarea ya hayan terminado: debe recuperarse la tarea, no el APK.
  taskRunning = false;
  await sandbox.module.exports.activate({ subscriptions: [] });
  assert.deepEqual(calls.filter(call => call[0] === 'start'),
    [['start', 'muondia@emulator-5554']],
    'VS Code reopens the stopped Flutter development task even with a stale Android PID');
  assert.equal(panels.size, 1, 'Reactivation reuses the existing Muondia panel');
  // Stress-test the generic registry without simulating a named second app.
  entries = Array.from({ length: 150 }, (_, i) => ({
    appId: `app-${i}`, label: `App ${i}`, serial: `device-${i}`, id: `app-${i}@device-${i}`,
    kind: 'external', active: true, deviceReady: true, status: 'running', epoch: String(i)
  }));
  await api.refresh();
  assert.equal(panels.size, 151, 'No fixed maximum of tabs; existing Muondia panel untouched');
  vscode.workspace.isTrusted = false;
  assert.equal(await sandbox.module.exports.activate({ subscriptions: [] }), undefined);
  console.log('PASS: F7 dev Auth, Muondia startup/recovery, no duplicate Flutter, viewer reopening, reconnect/stop, stress registry and workspace trust.');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
