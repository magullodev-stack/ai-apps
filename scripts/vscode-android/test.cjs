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
  assert.ok(treeProvider,
    'Activation must register the AI-APPS Android TreeDataProvider');
  const manifest = JSON.parse(
    fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8'));
  const menus = manifest.contributes.menus['view/item/context'];
  for (const [command, context, group] of [
    ['hideVisualAsset', 'visualAssetVisible', 'inline@1'],
    ['showVisualAsset', 'visualAssetHidden', 'inline@1'],
    ['replaceVisualAsset', 'visualAssetVisible', 'navigation@1'],
    ['deleteVisualAsset', 'visualAssetHidden', 'navigation@2'],
  ]) {
    assert.ok(menus.some(menu =>
      menu.command === 'aiAppsAndroid.' + command &&
      menu.when.includes(context) && menu.group === group),
    'The installed manifest must expose the native visual resource action: ' + command);
  }
  assert.equal(panels.size, 1, 'Startup restores only the registered Muondia session');
  assert.equal(panels.has('muondia@emulator-5554'), true);
  assert.equal(treeProvider.getTreeItem({ ...entries[0], active: false, status: 'starting' }).contextValue,
    'androidRunning', 'A starting session exposes Stop instead of a second Start');
  assert.equal(calls.some(call => call[0] !== 'open'), false,
    'A running development task is never started twice');
  // No duplicar la aplicación ni mostrar laboratorios inactivos en el árbol.
  const muondia = entries[0];
  entries = [
    muondia,
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
  let roots = treeProvider.getChildren();
  assert.equal(roots.length, 1, 'Only Muondia is visible; no duplicate or lab folder');
  assert.equal(roots[0].id, muondia.id);
  assert.equal(treeProvider.getTreeItem(roots[0]).collapsibleState,
    vscode.TreeItemCollapsibleState.Expanded,
    'Muondia itself is the experience explorer');
  const content = treeProvider.getChildren(roots[0]);
  assert.deepEqual(Array.from(content.filter(item => item.experienceExplorerNode),
    entry => entry.experienceExplorerNode.label),
    ['Auth', 'Primera experiencia', 'Home'],
    'Singleton groups are flattened');
  const layers = content.find(item => item.visualAssetNode);
  assert.ok(layers, 'Shared visual inspector is present under the app');
  assert.equal(treeProvider.getTreeItem(layers).label, 'Capas e imágenes');
  const layerFolders = treeProvider.getChildren(layers);
  assert.ok(layerFolders.some(item =>
    item.visualAssetNode.folderPath === 'assets/auth'),
    'Asset folders are discovered without screen-specific configuration');
  const firstExperience = treeProvider.getChildren(content[1]);
  assert.deepEqual(Array.from(firstExperience, entry => entry.experienceExplorerNode.label),
    ['Loading del robot', 'Test de bienvenida']);
  const states = treeProvider.getChildren(firstExperience[0]);
  assert.deepEqual(Array.from(states, item => item.experienceExplorerNode.state.id),
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
  const homeCommand = treeProvider.getTreeItem(content[2]).command;
  await commands.get(homeCommand.command)(...homeCommand.arguments);
  assert.ok(calls.at(-1).includes('home'),
    'Home is a single-click destination without an extra folder');
  calls.pop();
  const authCommand = treeProvider.getTreeItem(content[0]).command;
  await commands.get(authCommand.command)(...authCommand.arguments);
  assert.ok(calls.at(-1).includes('auth'),
    'Auth is a single-click destination without an extra folder');
  calls.pop();
  const authAssets = layerFolders.find(item =>
    item.visualAssetNode.folderPath === 'assets/auth');
  const fileNodes = treeProvider.getChildren(authAssets);
  const stars = fileNodes.find(item =>
    item.visualAssetNode.asset === 'assets/auth/Estrellas.png');
  assert.ok(stars, 'Auth stars are discoverable');
  const hide = treeProvider.getTreeItem(stars).command;
  await commands.get(hide.command)(...hide.arguments);
  assert.ok(calls.at(-1).includes('com.aiapps.muondia.DEV_ASSET_VISIBILITY'),
    'Inspector uses debug intent to toggle a resource');
  assert.ok(calls.at(-1).includes('false'));
  assert.equal(treeProvider.getTreeItem(stars).description, 'Oculta');
  calls.pop();
  // All registered laboratories remain accessible by management commands,
  // even though their nodes are absent from the everyday explorer.
  assert.equal((await api.list()).length, 7);
  entries = [muondia];
  await api.refresh();
  roots = treeProvider.getChildren();
  assert.equal(roots.length, 1);
  let invalidations = 0;
  treeProvider.onDidChangeTreeData(() => invalidations++);
  await api.refresh();
  await api.refresh();
  assert.equal(invalidations, 0,
    'Polling without session/catalog changes must not redraw expanded nodes');
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
