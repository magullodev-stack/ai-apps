const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { EventEmitter } = require('node:events');
const bundle = fs.readFileSync(path.resolve(__dirname, '../../.ai-apps/embedroid/extension/dist/extension.js'), 'utf8');
const panels = [], serializers = [], streams = [], disposals = [], titlesBeforeStream = [];
function panel(title) {
  const events = new EventEmitter();
  const messages = new EventEmitter();
  const result = { title, viewColumn: 1, webview: {
    options: {}, cspSource: 'test', asWebviewUri: uri => uri,
    onDidReceiveMessage: callback => messages.on('message', callback),
    postMessage: value => { result.messages.push(value); return Promise.resolve(true); }
  }, messages: [], onDidDispose: callback => events.on('dispose', callback),
    dispose() { result.disposed = true; events.emit('dispose'); }, reveal() { result.revealed = true; },
    ready() { messages.emit('message', { type: 'ready' }); },
    notify(message) { messages.emit('message', message); } };
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
  titlesBeforeStream.push(view.panel.title);
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
function createTestViews() {
  const views = createViews(Base, context, {}, { find() {} }, log);
  views.waitForDeviceBoot = async () => true;
  return views;
}
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function run() {
  const views = createTestViews();
  await Promise.all([views.openSession(a), views.openSession(a)]);
  assert.equal(views.views.size, 1); assert.equal(panels.length, 1);
  for (const item of panels) item.ready();
  assert.ok(panels[0].messages.some(item => item.type === 'session' && item.session.appId === 'muondia'));
  await views.openSession(a);
  assert.equal(panels.length, 1, 'Repeated selector only reveals');
  await views.openSession(a, true);
  assert.deepEqual(disposals, ['emulator-5554'], 'Reconnect renews only the current video bridge');
  assert.equal(panels[0].disposed, undefined);
  views.close(a.serial);
  assert.equal(views.views.size, 0);
  await views.openSession(a);
  assert.equal(views.views.size, 1, 'Closing and reopening affects only the viewer');
  const duplicate = panel('Old duplicate');
  await serializers[0].deserializeWebviewPanel(duplicate, { session: a });
  assert.equal(duplicate.disposed, true); assert.equal(views.views.size, 1);
  await assert.rejects(views.openSession({ ...a, appId: 'conflict' }), /another application/);
  const reopened = createTestViews();
  const restoredA = panel('QuizAI - emulator-5554');
  await serializers[1].deserializeWebviewPanel(restoredA, { serial: a.serial });
  assert.equal(titlesBeforeStream.at(-1), 'Muondia · emulator-5554',
    'The reserved emulator is named Muondia before attaching video');
  assert.equal(restoredA.title, 'Muondia · emulator-5554',
    'A legacy QuizAI tab is renamed directly to Muondia without an Android placeholder');
  await reopened.openSession(a);
  assert.equal(reopened.views.size, 1, 'Current session reconnects its persisted viewer');
  assert.equal(restoredA.title, 'Muondia · emulator-5554', 'Current registry restores the label');
  assert.equal(reopened.listSessions()[0]?.label, a.label);
  const migrated = createTestViews();
  const previousPanel = panel('Old application - emulator-5554');
  await serializers[2].deserializeWebviewPanel(previousPanel, {
    session: { serial: a.serial, appId: 'retired', label: 'Old application' }
  });
  assert.equal(previousPanel.disposed, true, 'Incompatible persisted identities are discarded');
  const countBeforeMigration = panels.length;
  await migrated.openSession(a);
  assert.equal(panels.length, countBeforeMigration + 1,
    'Current session opens a fresh panel after discarding obsolete state');
  assert.equal(panels.at(-1).title, 'Muondia · emulator-5554');
  const invalid = panel('Unknown');
  await serializers[2].deserializeWebviewPanel(invalid, undefined);
  assert.equal(invalid.disposed, true, 'Unidentified panels are discarded');
  const restoredDuplicate = panel('Duplicate');
  await serializers[1].deserializeWebviewPanel(restoredDuplicate, { serial: a.serial });
  assert.equal(restoredDuplicate.disposed, true, 'A duplicate of the same serial is discarded');
  // VS Code restores panels as Windows is still booting the emulator.
  const delayed = createTestViews();
  let releaseBoot;
  delayed.waitForDeviceBoot = () => new Promise(resolve => {
    releaseBoot = () => resolve(true);
  });
  const waitingPanel = panel('Saved from last Windows session');
  const oldStreamCount = streams.length;
  const restoration = serializers[3].deserializeWebviewPanel(
    waitingPanel, { serial: a.serial });
  await delay(0);
  assert.equal(streams.length, oldStreamCount,
    'Restored viewer must not attach scrcpy before Android finishes booting');
  releaseBoot();
  await restoration;
  assert.equal(streams.length, oldStreamCount + 1,
    'Exactly one stream starts when Android is ready');
  waitingPanel.ready();
  delayed.retryDelays = [8, 8, 8];
  waitingPanel.notify({ type: 'streamError' });
  waitingPanel.notify({ type: 'streamError' });
  await delay(35);
  assert.equal(streams.length, oldStreamCount + 2,
    'Duplicate stream errors schedule only one bounded recovery');
  assert.equal(delayed.views.get(a.serial).retryCount, 1);
  const recoveredView = delayed.views.get(a.serial);
  waitingPanel.notify({ type: 'frame', frames: 1 });
  waitingPanel.notify({ type: 'streamError' });
  await delay(35);
  assert.equal(streams.length, oldStreamCount + 2,
    'Once video rendered, startup recovery must not launch another stream');
  waitingPanel.notify({ type: 'retry' });
  await delay(5);
  assert.equal(recoveredView.retryCount, 0,
    'Explicit Retry clears the automatic retry budget');
  assert.equal(streams.length, oldStreamCount + 3,
    'Explicit Retry still replaces only the viewer bridge');
  delayed.views.get(a.serial).videoFrames = 0;
  waitingPanel.notify({ type: 'streamError' });
  waitingPanel.dispose();
  await delay(35);
  assert.equal(streams.length, oldStreamCount + 3,
    'Closing the panel cancels any queued reconnect');

  assert.ok(bundle.includes('onWebviewPanel') === false); // Activation belongs in manifest.
  const builtWebview = fs.readFileSync(path.resolve(__dirname, '../../.ai-apps/embedroid/extension/media/webview.js'), 'utf8');
  assert.ok(builtWebview.includes('x.setState({serial:t.session.serial})'));
  assert.ok(!builtWebview.includes('x.setState({session:t.session})'));
  assert.ok(builtWebview.includes('v.onclose=null;v.close()'));
  assert.ok(builtWebview.includes('x.postMessage({type:"streamError"})'));
  assert.ok(fs.existsSync(path.resolve(__dirname, '../../.ai-apps/embedroid/extension/boot-ready.cjs')));
  console.log('PASS: Muondia viewer identity, boot-gated restoration, bounded recovery and safe cancellation.');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
