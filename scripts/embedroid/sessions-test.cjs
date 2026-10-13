const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { EventEmitter } = require('node:events');
const bundle = fs.readFileSync(path.resolve(__dirname, '../../.ai-apps/embedroid/extension/dist/extension.js'), 'utf8');
const panels = [], serializers = [], streams = [], disposals = [];
function panel(title) {
  const events = new EventEmitter();
  const messages = new EventEmitter();
  const result = { title, viewColumn: 1, webview: {
    options: {}, cspSource: 'test', asWebviewUri: uri => uri,
    onDidReceiveMessage: callback => messages.on('message', callback),
    postMessage: value => { result.messages.push(value); return Promise.resolve(true); }
  }, messages: [], onDidDispose: callback => events.on('dispose', callback),
    dispose() { result.disposed = true; events.emit('dispose'); }, reveal() { result.revealed = true; },
    ready() { messages.emit('message', { type: 'ready' }); } };
  panels.push(result); return result;
}
const vscode = {
  TreeItem: class {}, Uri: { joinPath: (...parts) => parts.join('/') },
  ViewColumn: { Active: 1, Beside: -2 }, workspace: { getConfiguration: () => ({ get: (_, fallback) => fallback }) },
  window: { createWebviewPanel: (_, title) => panel(title),
    registerWebviewPanelSerializer: (type, serializer) => { serializers.push(serializer); return { dispose() {} }; },
    tabGroups: { all: [] } }, commands: { executeCommand: async () => {} }
};
const sandbox = { module: { exports: {} }, Buffer, console, process, setTimeout, clearTimeout, setInterval, clearInterval,
  URLSearchParams, require(name) { if (name === 'vscode') return vscode; return require(name); } };
vm.runInNewContext(`${bundle}\n;module.exports.Base = $e;`, sandbox);
const Base = sandbox.module.exports.Base;
Base.prototype.attachStream = async function(key, serial) {
  const view = this.views.get(key);
  if (view.bridge) await view.bridge.dispose();
  view.serial = serial;
  view.bridge = { dispose: async () => { disposals.push(serial); } };
  streams.push(serial);
};
const moduleSandbox = { module: { exports: {} }, require: name => name === 'vscode' ? vscode : require(name) };
vm.runInNewContext(fs.readFileSync(path.join(__dirname, 'sessions.cjs'), 'utf8'), moduleSandbox);
const { createViews } = moduleSandbox.module.exports;
const context = { subscriptions: [], extensionUri: 'extension', extensionPath: 'extension' };
const log = { debug() {}, warn() {} };
const a = { appId: 'muondia', label: 'Muondia', serial: 'emulator-5554' };
const b = { appId: 'lab-abcdef012345', label: 'Lab', serial: 'emulator-5556' };
async function run() {
  const views = createViews(Base, context, {}, { find() {} }, log);
  await Promise.all([views.openSession(a), views.openSession(a), views.openSession(b)]);
  assert.equal(views.views.size, 2); assert.equal(panels.length, 2);
  for (const item of panels) item.ready();
  assert.ok(panels[0].messages.some(item => item.type === 'session' && item.session.appId === 'muondia'));
  assert.equal(panels[1].title, 'Lab · emulator-5556');
  await views.openSession(a);
  assert.equal(panels.length, 2, 'Repeated selector only reveals');
  await views.openSession(b, true);
  assert.deepEqual(disposals, ['emulator-5556'], 'Reconnect disposes only its own bridge');
  assert.equal(panels[0].disposed, undefined);
  views.close(b.serial);
  assert.equal(views.views.size, 1);
  await views.openSession(b);
  assert.equal(views.views.size, 2, 'Closing and reopening is independent of app runtime');
  const duplicate = panel('Old duplicate');
  await serializers[0].deserializeWebviewPanel(duplicate, { session: a });
  assert.equal(duplicate.disposed, true); assert.equal(views.views.size, 2);
  await assert.rejects(views.openSession({ ...a, appId: 'conflict' }), /another application/);
  const reopened = createViews(Base, context, {}, { find() {} }, log);
  const restoredA = panel('Restored A'), restoredB = panel('Restored B');
  await serializers[1].deserializeWebviewPanel(restoredA, { session: a });
  await serializers[1].deserializeWebviewPanel(restoredB, { session: b });
  assert.equal(restoredB.disposed, true, 'Discarded lab preview is not restored at editor startup');
  await reopened.openSession(a); await reopened.openSession(b);
  assert.equal(reopened.views.size, 2, 'Explicit lab selection still works');
  assert.equal(restoredA.title, 'Muondia · emulator-5554');
  assert.equal(reopened.listSessions().find(item => item.serial === b.serial)?.label, b.label);
  const migrated = createViews(Base, context, {}, { find() {} }, log);
  const legacy = panel('AI_APPS_Dev');
  await serializers[2].deserializeWebviewPanel(legacy, undefined);
  const countBeforeMigration = panels.length;
  await migrated.openSession({ ...a, avdName: 'AI_APPS_Dev' });
  assert.equal(panels.length, countBeforeMigration, 'Known legacy AVD panel is adopted, not duplicated');
  assert.equal(legacy.title, 'Muondia · emulator-5554');
  // A persisted app identity is not authoritative after an app migration.
  const stale = createViews(Base, context, {}, { find() {} }, log);
  const stalePanel = panel('Retired - emulator-5554');
  await serializers[3].deserializeWebviewPanel(stalePanel, {
    session: { serial: a.serial, appId: 'retired', label: 'Retired' }
  });
  assert.equal(stalePanel.title, 'Android · emulator-5554',
    'Old app labels must never reappear while the session is reconciling');
  const beforeStaleReconnect = panels.length;
  await stale.openSession(a);
  assert.equal(panels.length, beforeStaleReconnect, 'Reconcile without creating another panel');
  assert.equal(stalePanel.title, 'Muondia · emulator-5554', 'Current registry identity wins');

  const oldTitle = createViews(Base, context, {}, { find() {} }, log);
  const oldPanel = panel('Retired - emulator-5554');
  await serializers[4].deserializeWebviewPanel(oldPanel, undefined);
  assert.equal(oldPanel.title, 'Android', 'Unidentified panels must not retain retired labels');
  const beforeOldTitle = panels.length;
  await oldTitle.openSession(a);
  assert.equal(panels.length, beforeOldTitle, 'Adopt a legacy panel using its original serial');
  assert.equal(oldPanel.title, 'Muondia · emulator-5554');
  assert.ok(bundle.includes('onWebviewPanel') === false); // Activation belongs in manifest.
  const builtWebview = fs.readFileSync(path.resolve(__dirname, '../../.ai-apps/embedroid/extension/media/webview.js'), 'utf8');
  assert.ok(builtWebview.includes('x.setState({session:t.session})'));
  assert.ok(builtWebview.includes('v.onclose=null;v.close()'));
  console.log('PASS: bundled manager, concurrent deduplication, two apps/devices, independent close/reconnect, serializer/startup race, restore and persistent webview identity.');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
