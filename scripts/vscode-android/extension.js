const vscode = require('vscode');
const fs = require('node:fs');
const path = require('node:path');
const EMBEDROID_ID = 'magullodev.ai-apps-embedroid';

async function activate(context) {
  const folder = (vscode.workspace.workspaceFolders || []).find(item =>
    fs.existsSync(path.join(item.uri.fsPath, 'AGENTS.md')) &&
    fs.existsSync(path.join(item.uri.fsPath, 'scripts/start-dev-session.ps1')));
  if (!folder || !vscode.workspace.isTrusted) return;
  const { Sessions } = require(path.join(folder.uri.fsPath, 'scripts/android/sessions.cjs'));
  const { Windows } = require(path.join(folder.uri.fsPath, 'scripts/android/windows.cjs'));
  const output = vscode.window.createOutputChannel('AI-APPS Android');
  const service = new Sessions(folder.uri.fsPath, new Windows(folder.uri.fsPath));
  const changed = new vscode.EventEmitter();
  const shown = new Map();
  const disconnected = new Set();
  let sessions = [], refreshing, disposed = false;
  const extension = vscode.extensions.getExtension(EMBEDROID_ID);
  if (!extension) throw new Error('Instala EmbeDroid con scripts/install-embedroid.ps1.');
  const viewer = await extension.activate();
  if (!viewer?.openSession) throw new Error('Actualiza EmbeDroid a la distribución multiemulador.');
  const config = vscode.workspace.getConfiguration('embedroid', folder.uri);
  await config.update('openIn', 'active', vscode.ConfigurationTarget.Workspace);
  await config.update('headless', true, vscode.ConfigurationTarget.Workspace);

  function report(error) {
    const message = String(error.message || error);
    output.appendLine('ERROR: ' + message);
    vscode.window.showErrorMessage('AI-APPS Android: ' + message);
  }
  async function open(session, reconnect = false) {
    if (!session.deviceReady) throw new Error('El dispositivo no está conectado: ' + session.serial);
    await viewer.openSession(session, reconnect);
    shown.set(session.id, session.epoch);
    output.appendLine(`${reconnect ? 'Reconectada' : 'Abierta'}: ${session.label} · ${session.serial}`);
  }
  async function refresh() {
    if (refreshing) return refreshing;
    refreshing = (async () => {
      sessions = await service.list();
      if (disposed) return sessions;
      changed.fire();
      const views = viewer.listSessions?.() || [];
      for (const session of sessions) {
        if (!session.deviceReady && views.some(view => view.serial === session.serial)) disconnected.add(session.id);
      }
      for (const session of sessions.filter(item => item.active)) {
        if (shown.get(session.id) === session.epoch && !disconnected.has(session.id)) continue;
        const reconnect = (shown.has(session.id) || disconnected.has(session.id)) &&
          views.some(view => view.serial === session.serial);
        try { await open(session, reconnect); disconnected.delete(session.id); }
        catch (error) { output.appendLine(`${session.id}: ${error.message}`); }
      }
      return sessions;
    })();
    try { return await refreshing; } finally { refreshing = undefined; }
  }
  function choices(items) {
    return items.map(session => ({ label: session.label, description: session.serial,
      detail: `${session.status} · ${session.appId}`, session }));
  }
  async function pick(items, title, multiple = false) {
    return vscode.window.showQuickPick(choices(items), { title, canPickMany: multiple, matchOnDetail: true });
  }
  async function chooseAction(action, supplied) {
    await refresh();
    const item = supplied?.session || supplied;
    const session = item?.id ? service.find(item.id) :
      (await pick(sessions.filter(item => item.kind !== 'external'), `${action === 'start' ? 'Iniciar' : 'Detener'} sesión Android`))?.session;
    if (!session) return;
    const id = session.id || `${session.appId}@${session.serial}`;
    await service[action](id);
    if (action === 'start') shown.delete(id);
    await refresh();
  }
  async function register() {
    const appId = await vscode.window.showInputBox({ title: 'Identificador de aplicación', prompt: 'Ejemplo: lab-counter' });
    if (!appId) return;
    const label = await vscode.window.showInputBox({ title: 'Nombre de la aplicación', value: appId });
    if (!label) return;
    const directories = await vscode.window.showOpenDialog({ canSelectFiles: false, canSelectFolders: true,
      canSelectMany: false, openLabel: 'Proyecto Flutter' });
    if (!directories?.[0]) return;
    const occupied = new Set(sessions.map(item => item.serial));
    let port = 5556;
    while (occupied.has(`emulator-${port}`)) port += 2;
    const serial = await vscode.window.showInputBox({ title: 'Dispositivo independiente', value: `emulator-${port}` });
    if (!serial) return;
    const avdName = await vscode.window.showInputBox({ title: 'AVD independiente', value: `AI_APPS_${appId.replace(/-/g, '_')}` });
    if (!avdName) return;
    const packageName = await vscode.window.showInputBox({ title: 'Paquete Android de la aplicación', prompt: 'applicationId del proyecto Flutter' });
    if (!packageName) return;
    service.register({ appId, label, serial, avdName, packageName, kind: 'flutter', projectPath: directories[0].fsPath });
    await refresh();
  }
  const tree = {
    onDidChangeTreeData: changed.event,
    getChildren: () => sessions,
    getTreeItem(session) {
      const item = new vscode.TreeItem(`${session.label} · ${session.serial}`);
      item.description = session.status;
      item.tooltip = `${session.appId} · ${session.serial}\n${session.projectPath || 'Sesión externa'}`;
      item.contextValue = session.kind === 'external' ? 'androidExternal' :
        session.active || ['starting', 'stopping'].includes(session.status) ? 'androidRunning' : 'androidStopped';
      item.iconPath = new vscode.ThemeIcon(session.active ? 'device-mobile' : 'circle-outline');
      item.command = { command: 'aiAppsAndroid.open', title: 'Visualizar sesión', arguments: [session] };
      return item;
    }
  };
  function command(name, handler) {
    context.subscriptions.push(vscode.commands.registerCommand('aiAppsAndroid.' + name,
      (...args) => Promise.resolve().then(() => handler(...args)).catch(report)));
  }
  command('select', async () => {
    await refresh();
    const selected = await pick(sessions.filter(item => item.deviceReady), 'Visualizar sesiones Android', true);
    for (const item of selected || []) await open(item.session);
  });
  command('open', async supplied => {
    await refresh();
    const session = sessions.find(item => item.id === supplied?.id);
    if (session) await open(session);
  });
  command('reconnect', async supplied => {
    await refresh();
    const session = supplied?.id ? sessions.find(item => item.id === supplied.id) :
      (await pick(sessions.filter(item => item.deviceReady), 'Reconectar un visor Android'))?.session;
    if (session) await open(session, true);
  });
  command('start', supplied => chooseAction('start', supplied));
  command('stop', supplied => chooseAction('stop', supplied));
  command('register', register);
  command('refresh', refresh);
  const status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left);
  status.text = '$(device-mobile) Android'; status.command = 'aiAppsAndroid.select'; status.show();
  const interval = setInterval(() => refresh().catch(error => output.appendLine(error.message)), 5000);
  context.subscriptions.push(output, changed, status,
    vscode.window.createTreeView('aiAppsAndroid.sessions', { treeDataProvider: tree }),
    { dispose() { disposed = true; clearInterval(interval); } });
  await refresh().catch(report);
  return { refresh, list: () => sessions, service };
}
function deactivate() {}
module.exports = { activate, deactivate };
