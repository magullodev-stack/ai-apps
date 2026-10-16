const vscode = require('vscode');
const fs = require('node:fs');
const path = require('node:path');
const EMBEDROID_ID = 'magullodev.ai-apps-embedroid';
const { createExperienceExplorer } = require('./explorer.cjs');
const { createVisualAssetInspector } = require('./asset-inspector.cjs');
const { planVisualRenames } = require('./visual-renames.cjs');

async function activate(context) {
  const folder = (vscode.workspace.workspaceFolders || []).find(item =>
    fs.existsSync(path.join(item.uri.fsPath, 'AGENTS.md')) &&
    fs.existsSync(path.join(item.uri.fsPath, 'scripts/start-dev-session.ps1')));
  if (!folder || !vscode.workspace.isTrusted) return;
  const { Sessions } = require(path.join(folder.uri.fsPath, 'scripts/android/sessions.cjs'));
  const { Windows } = require(path.join(folder.uri.fsPath, 'scripts/android/windows.cjs'));
  const output = vscode.window.createOutputChannel('AI-APPS Android');
  const service = new Sessions(folder.uri.fsPath, new Windows(folder.uri.fsPath));
  const explorer = createExperienceExplorer(vscode, service, message => output.appendLine(message));
  const assets = createVisualAssetInspector(vscode, service, message => output.appendLine(message));
  const changed = new vscode.EventEmitter();
  const shown = new Map();
  const disconnected = new Set();
  let sessions = [], refreshing, disposed = false, firstRefresh = true;
  let lastTreeSnapshot;
  const extension = vscode.extensions.getExtension(EMBEDROID_ID);
  if (!extension) throw new Error('Instala EmbeDroid con scripts/install-embedroid.ps1.');
  const viewer = await extension.activate();
  if (!viewer?.openSession) throw new Error('Actualiza EmbeDroid a la distribución multiemulador.');
  const config = vscode.workspace.getConfiguration('embedroid', folder.uri);
  await config.update('openIn', 'active', vscode.ConfigurationTarget.Workspace);
  await config.update('headless', true, vscode.ConfigurationTarget.Workspace);

  // Flutter sigue perteneciendo a la extensión oficial Dart. Solo le
  // notificamos los cambios del repositorio, incluso los recibidos por Git.
  let updateTimer;
  let pendingResourceChange = false;
  let pendingBundleChange = false;
  let pendingSourceChange = false;
  const savedInEditor = new Map();
  const rootPath = folder.uri.fsPath;
  const relativeFile = uri => path.relative(rootPath, uri.fsPath).replace(/\\/g, '/');
  const activeMuondia = () => {
    const session = vscode.debug.activeDebugSession;
    return session?.type === 'dart' && session.name === 'Muondia';
  };
  async function updateFlutter() {
    if (!activeMuondia()) return;
    const rebuild = pendingBundleChange;
    const restart = pendingResourceChange;
    if (!rebuild && !restart && !pendingSourceChange) return;
    pendingBundleChange = false;
    pendingResourceChange = false;
    pendingSourceChange = false;
    try {
      const command = rebuild ? 'workbench.action.debug.restart' :
        restart ? 'dart.hotRestart' : 'dart.hotReload';
      await vscode.commands.executeCommand(command);
      output.appendLine(rebuild ? 'Recurso nuevo incorporado a Flutter.' :
        restart ? 'Recursos actualizados en Flutter.' : 'Código actualizado en Flutter.');
    } catch (error) {
      output.appendLine('No se pudo actualizar Flutter: ' + String(error.message || error));
    }
  }
  function changedFile(uri, event = 'change') {
    const file = relativeFile(uri);
    const shared = file.startsWith('shared/') ||
      file.startsWith('ai/flutter_client/');
    if (file.includes('/build/') || file.includes('/.dart_tool/') ||
        file.includes('/.git/') || file.includes('/node_modules/')) return;
    // Support all registered Flutter apps, not only Muondia.
    const appFile = sessions.map(session => ({
      session, local: session.projectPath
        ? path.relative(session.projectPath, uri.fsPath).replace(/\\/g, '/')
        : '',
    })).find(({local,session}) => session.kind !== 'external' &&
      local && !local.startsWith('../') && !path.isAbsolute(local));
    const local = appFile?.local || '';
    const source = file.endsWith('.dart') &&
      (shared || local.startsWith('lib/'));
    const resource = !!appFile &&
      (local.startsWith('assets/') || local === 'pubspec.yaml');
    const catalog = local === 'lib/app/development/experiences.json';
    if (!source && !resource && !catalog) return;
    // UI changes must appear as soon as the filesystem event is delivered.
    changed.fire();
    if (source && Date.now() - (savedInEditor.get(file) || 0) < 1500) return;
    if (resource) {
      if (event !== 'change' || local === 'pubspec.yaml') {
        pendingBundleChange = true;
      } else pendingResourceChange = true;
    } else pendingSourceChange = true;
    clearTimeout(updateTimer);
    updateTimer = setTimeout(() => void updateFlutter(), 900);
  }
  const watchPatterns = [
    'apps/**/*',
    'shared/**/*',
    'ai/flutter_client/**/*',
  ];
  if (vscode.workspace.createFileSystemWatcher) {
    for (const pattern of watchPatterns) {
      const watcher = vscode.workspace.createFileSystemWatcher(
        new vscode.RelativePattern(folder, pattern),
      );
      watcher.onDidCreate(uri => changedFile(uri, 'create'), null, context.subscriptions);
      watcher.onDidChange(uri => changedFile(uri), null, context.subscriptions);
      watcher.onDidDelete(uri => changedFile(uri, 'delete'), null, context.subscriptions);
      context.subscriptions.push(watcher);
    }
  }
  // Renaming in VS Code's file explorer updates the source of truth
  // together: Dart literals, visual ownership markers, pubspec and the
  // catalog's directory association. External git/filesystem renames are
  // still mirrored by the resource snapshot; their code needs explicit care.
  const renameDocumentsToSave = new Map();
  if (vscode.workspace.onWillRenameFiles) {
    context.subscriptions.push(vscode.workspace.onWillRenameFiles(event => {
      if (assets.isManagedRename()) return;
      const proposed = (async () => {
        const edit = new vscode.WorkspaceEdit();
        const planned = new Map();
        for (const session of sessions) {
          if (!session.projectPath || session.kind === 'external') continue;
          for (const item of planVisualRenames(session, event.files)) {
            if (planned.has(item.filename)) {
              throw new Error('El mismo archivo pertenece a dos aplicaciones.');
            }
            planned.set(item.filename, item);
          }
        }
        if (!planned.size) return undefined;
        const modified = [];
        for (const item of planned.values()) {
          const uri = vscode.Uri.file(item.filename);
          const doc = await vscode.workspace.openTextDocument(uri);
          if (doc.isDirty || doc.getText() !== item.original) {
            throw new Error('Guarda ' + path.basename(item.filename) +
              ' antes de renombrar recursos visuales.');
          }
          edit.replace(uri, new vscode.Range(
            doc.positionAt(0), doc.positionAt(item.original.length)),
            item.updated);
          modified.push(doc);
        }
        for (const doc of modified) renameDocumentsToSave.set(doc.uri.fsPath, doc);
        return edit;
      })();
      event.waitUntil(proposed);
    }));
  }
  if (vscode.workspace.onDidRenameFiles) {
    context.subscriptions.push(vscode.workspace.onDidRenameFiles(() => {
      changed.fire();
      for (const doc of renameDocumentsToSave.values()) {
        Promise.resolve(doc.save()).catch(report);
      }
      renameDocumentsToSave.clear();
    }));
  }

  if (vscode.workspace.onDidSaveTextDocument) {
    context.subscriptions.push(
      vscode.workspace.onDidSaveTextDocument(document => {
        savedInEditor.set(relativeFile(document.uri), Date.now());
      }),
    );
  }
  context.subscriptions.push({ dispose() { clearTimeout(updateTimer); } });

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
      const initial = firstRefresh;
      firstRefresh = false;
      // La APK instalada no demuestra que Flutter siga conectado.
      // Al abrir VS Code, recuperar la tarea de desarrollo si esta parada;
      // nunca abrir una APK antigua con adb ni lanzar otro Flutter.
      if (initial) {
        const developmentSession = sessions.find(item => item.kind === 'development-task');
        if (developmentSession) {
          try {
            if (!(await service.platform.taskRunning())) {
              await service.start(developmentSession.id);
            }
          } catch (error) {
            output.appendLine('Arranque de desarrollo Muondia: ' + error.message);
          }
        }
      }
      // El sondeo de dispositivos se ejecuta cada 5 segundos, pero el
      // árbol no debe reconstruirse mientras el usuario lo despliega.
      const currentTreeSnapshot = JSON.stringify(sessions.map(session => [
        session.id, session.label, session.serial, session.status,
        session.active, session.deviceReady, session.epoch,
        session.projectPath, session.packageName, session.kind,
      ]));
      const catalogChanged = explorer.refresh(sessions);
      const visualChanged = assets.refresh(sessions);
      if (lastTreeSnapshot !== currentTreeSnapshot ||
          catalogChanged || visualChanged) {
        lastTreeSnapshot = currentTreeSnapshot;
        changed.fire();
      }
      const views = viewer.listSessions?.() || [];
      for (const session of sessions) {
        if (!session.deviceReady && views.some(view => view.serial === session.serial)) disconnected.add(session.id);
      }
      for (const session of sessions.filter(item => item.active)) {
        // Restore Muondia first. Other registered applications can be opened explicitly.
        if (initial && session.kind !== 'development-task') {
          shown.set(session.id, session.epoch);
          continue;
        }
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
    const appId = await vscode.window.showInputBox({ title: 'Identificador de aplicación', prompt: 'Ejemplo: app-demo' });
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
  // Una única jerarquía: aplicación -> experiencias -> estados e imágenes.
  // Las sesiones de laboratorio inactivas siguen registradas y disponibles
  // por los comandos de administración, pero no ocupan espacio en el árbol.
  const isVisibleSession = session =>
    session.kind === 'development-task' || session.active;
  const wrapExperience = entry => ({ experienceExplorerNode: entry });
  const experiencesOf = session => explorer.provider.getChildren({
    kind: 'app',
    session,
  });
  let experienceView;
  function showExplorerLocation() {
    const location = explorer.activeLocation();
    if (!location || !experienceView) return;
    const where = location.mode === 'real'
      ? location.sessionLabel + ' · RECORRIDO REAL'
      : location.sessionLabel + ' · ' + location.group + ' / ' +
          location.experience + (location.state ? ' / ' + location.state : '');
    // Es la última orden solicitada desde el explorador; no se atribuye
    // una telemetría de navegación real que el dispositivo no proporciona.
    experienceView.description = where;
    status.tooltip = 'Última selección en el explorador: ' + where;
  }
  const tree = {
    onDidChangeTreeData: changed.event,
    getChildren(parent) {
      if (parent === undefined) return sessions.filter(isVisibleSession);
      if (parent?.experienceExplorerNode) {
        const entry = parent.experienceExplorerNode;
        // Una experiencia con una sola vista se abre al pulsar su nombre:
        // no añadir un estado "Vista inicial" redundante bajo sus imágenes.
        const children = entry.kind === 'experience' &&
            entry.item.states.length === 1
          ? []
          : explorer.provider.getChildren(entry).map(wrapExperience);
        if (entry.kind === 'experience') {
          children.push(...assets.forExperience(entry.session, entry.item)
            .map(visualAssetNode => ({ visualAssetNode })));
        }
        return children;
      }
      if (parent?.visualAssetNode) return [];
      if (parent?.id && parent?.serial) {
        return experiencesOf(parent).map(wrapExperience);
      }
      return [];
    },
    getTreeItem(session) {
      if (session.experienceExplorerNode) {
        const entry = session.experienceExplorerNode;
        const item = explorer.provider.getTreeItem(entry);
        // Auth/Home tienen una sola vista y antes eran hojas clicables.
        // Conservan su comando de vista previa; la flecha despliega imágenes.
        if (entry.kind === 'experience' &&
            item.collapsibleState === vscode.TreeItemCollapsibleState.None &&
            assets.forExperience(entry.session, entry.item).length) {
          item.collapsibleState = vscode.TreeItemCollapsibleState.Collapsed;
        }
        return item;
      }
      if (session.visualAssetNode) {
        return assets.getTreeItem(session.visualAssetNode);
      }
      const hasExperiences = experiencesOf(session).length > 0;
      const item = new vscode.TreeItem(
        `${session.label} · ${session.serial}`,
        hasExperiences
          ? vscode.TreeItemCollapsibleState.Expanded
          : vscode.TreeItemCollapsibleState.None,
      );
      item.id = `android-session:${session.id}`;
      item.description = session.status;
      item.tooltip = `${session.appId} · ${session.serial}\n${session.projectPath || 'Sesión externa'}`;
      item.contextValue = session.kind === 'external' ? 'androidExternal' :
        session.active || ['starting', 'stopping'].includes(session.status) ? 'androidRunning' : 'androidStopped';
      item.iconPath = new vscode.ThemeIcon(session.active ? 'device-mobile' : 'circle-outline');
      if (!hasExperiences) {
        item.command = {
          command: 'aiAppsAndroid.open',
          title: 'Visualizar sesión',
          arguments: [session],
        };
      }
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
    const session = supplied?.id ? sessions.find(item => item.id === supplied.id) :
      (await pick(sessions.filter(item => item.deviceReady), 'Visualizar una sesión Android'))?.session;
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
  command('preview', async (sessionId, experience, state) => {
    await explorer.open(sessionId, experience, state);
    changed.fire();
    showExplorerLocation();
  });
  command('realFlow', async sessionId => {
    await explorer.openReal(sessionId);
    changed.fire();
    showExplorerLocation();
  });
  command('findExperience', async () => {
    const targets = explorer.findTargets();
    if (!targets.length) {
      throw new Error('No hay pantallas disponibles en los emuladores conectados.');
    }
    const selected = await vscode.window.showQuickPick(targets, {
      placeHolder: 'Buscar por aplicación, categoría, pantalla o estado',
      matchOnDescription: true,
      matchOnDetail: true,
    });
    if (!selected) return;
    if (selected.mode === 'real') {
      await explorer.openReal(selected.sessionId);
    } else {
      await explorer.open(selected.sessionId, selected.experienceId, selected.stateId);
    }
    changed.fire();
    showExplorerLocation();
  });
  // El ojo es una acción inline nativa. Se mantiene también el clic de fila.
  const toggleNode = async node => {
    const entry = assets.resolveNode(node);
    await assets.toggle(entry.session.id, entry.asset);
    changed.fire();
  };
  command('toggleVisualAsset', async (node, asset) => {
    if (typeof node === 'string') {
      await assets.toggle(node, asset);
      changed.fire();
    } else {
      await toggleNode(node);
    }
  });
  command('hideVisualAsset', toggleNode);
  command('showVisualAsset', toggleNode);
  command('replaceVisualAsset', async node => {
    if (await assets.replaceImage(node)) changed.fire();
  });
  command('renameVisualAsset', async node => {
    if (await assets.renameImage(node)) changed.fire();
  });
  command('pendingVisualAsset', node => assets.pendingInfo(node));
  command('deleteVisualAsset', async node => {
    if (await assets.deleteImage(node)) changed.fire();
  });
  command('auth', async () => {
    // Entregar la orden a la Activity de Muondia directamente: el visor
    // EmbeDroid y Android pueden filtrar F7 como evento de teclado.
    const target = (await service.list()).find(session =>
      session.kind === 'development-task' &&
      session.appId === 'muondia' &&
      session.serial === 'emulator-5554');
    if (!target?.deviceReady) {
      throw new Error('El emulador de Muondia no está conectado.');
    }
    const pid = await service.platform.appPid({
      serial: target.serial,
      packageName: 'com.aiapps.muondia',
    });
    if (!pid) throw new Error('Muondia no está ejecutándose en el emulador.');
    await service.platform.run(service.platform.adb, [
      '-s', target.serial,
      'shell', 'am', 'start',
      '-n', 'com.aiapps.muondia/.MainActivity',
      '-a', 'com.aiapps.muondia.DEV_SHOW_AUTH',
      '-f', '0x20000000',
    ]);
    output.appendLine('Vista Auth solicitada a Muondia (canal de desarrollo).');
    explorer.rememberPreview(target.id, 'auth', 'inicio');
    changed.fire();
    showExplorerLocation();
  });
  const status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left);
  status.text = '$(device-mobile) Android'; status.command = 'aiAppsAndroid.select'; status.show();
  const interval = setInterval(() => refresh().catch(error => output.appendLine(error.message)), 5000);
  context.subscriptions.push(output, changed, status,
    { dispose() { disposed = true; clearInterval(interval); } });
  experienceView = vscode.window.createTreeView('aiAppsAndroid.sessions', {
    treeDataProvider: tree,
  });
  context.subscriptions.push(experienceView);
  await refresh().catch(report);
  return { refresh, list: () => sessions, service };
}
function deactivate() {}
module.exports = { activate, deactivate };
