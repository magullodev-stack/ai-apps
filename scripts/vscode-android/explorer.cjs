'use strict';
const fs = require('node:fs');
const path = require('node:path');

// La app declara las experiencias; no inferirlas de sus assets.
const CATALOG = 'lib/app/development/experiences.json';
const ID = /^[a-z][a-z0-9_-]*$/;
const PACKAGE = /^[a-zA-Z][\w]*(?:\.[a-zA-Z][\w]*)+$/;

function readCatalog(session) {
  if (!session || session.kind === 'external' || !session.projectPath ||
      !PACKAGE.test(session.packageName || '')) return null;
  const file = path.join(session.projectPath, CATALOG);
  if (!fs.existsSync(file)) return null;
  const doc = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (doc.version !== 1 || !Array.isArray(doc.experiences) ||
      doc.activity !== session.packageName + '/.MainActivity') {
    throw new Error('Catálogo de experiencias inválido: ' + file);
  }
  // El protocolo de estado se lee solo desde archivos privados de APK debug.
  // El catálogo no puede inyectar una ruta arbitraria en adb run-as.
  if (doc.activeLocationFile !== undefined &&
      doc.activeLocationFile !== 'files/ai_apps_active_experience.txt') {
    throw new Error('Archivo de estado de vista inválido: ' + file);
  }
  // Cada aplicación declara explícitamente si admite regresar a su flujo
  // auténtico desde esta sesión debug. Nunca ejecutar intents arbitrarios.
  if (doc.realFlowAction !== undefined &&
      doc.realFlowAction !== session.packageName + '.DEV_OPEN_REAL_FLOW') {
    throw new Error('Acción de recorrido real inválida: ' + file);
  }
  const ids = new Set();
  // Cada carpeta visual tiene una sola pantalla propietaria.
  // No pueden solaparse: ocultar, sustituir o eliminar un recurso no
  // debe afectar accidentalmente a otra experiencia.
  const assetDirectories = [];
  const isAssetDirectory = dir => typeof dir === 'string' &&
    dir.split('/').length >= 2 && dir.startsWith('assets/') &&
    dir.split('/').slice(1).every(part => part &&
      part !== '.' && part !== '..' && !part.startsWith('.') &&
      !/[\\:*?"<>|\x00-\x1f]/.test(part));
  for (const item of doc.experiences) {
    if (!ID.test(item.id) || ids.has(item.id) ||
        typeof item.label !== 'string' || !item.label.trim() ||
        typeof item.group !== 'string' || !item.group.trim() ||
        !Array.isArray(item.states) || !item.states.length) {
      throw new Error('Experiencia inválida: ' + file);
    }
    ids.add(item.id);
    if (item.assetDirectories !== undefined &&
        (!Array.isArray(item.assetDirectories) ||
          item.assetDirectories.some(dir => !isAssetDirectory(dir)))) {
      throw new Error('Carpetas visuales inválidas: ' + file);
    }
    for (const dir of item.assetDirectories || []) {
      if (assetDirectories.some(other =>
          other === dir || other.startsWith(dir + '/') ||
          dir.startsWith(other + '/'))) {
        throw new Error('Carpetas visuales compartidas entre experiencias: ' + file);
      }
      assetDirectories.push(dir);
    }
    const stateIds = new Set();
    for (const state of item.states) {
      if (!ID.test(state.id) || stateIds.has(state.id) ||
          typeof state.label !== 'string' || !state.label.trim()) {
        throw new Error('Estado de experiencia inválido: ' + file);
      }
      stateIds.add(state.id);
    }
  }
  return doc;
}

function createExperienceExplorer(vscode, service, report) {
  let sessions = [];
  let lastCatalogSnapshot;
  const active = new Map();
  let lastLocation = null;
  const requestedAt = new Map();
  const node = (kind, label, session, item, state) => ({kind,label,session,item,state});
  function remember(session, mode, experience, state) {
    const location = {sessionId: session.id, sessionLabel: session.label,
      mode, experienceId: experience?.id || null, stateId: state?.id || null,
      group: experience?.group || null, experience: experience?.label || null,
      state: state?.label || null};
    active.set(session.id, location);
    lastLocation = location;
    return location;
  }
  // Los cambios del explorador se notifican desde el árbol principal de
  // AI-APPS Android. Este proveedor interno no registra un emitter propio.
  const provider = {
    getChildren(parent) {
      if (!parent) return sessions.filter(s => readCatalog(s))
        .map(s => node('app', s.label, s));
      const catalog = readCatalog(parent.session);
      if (!catalog) return [];
      if (parent.kind === 'app') {
        // Mantener siempre las categorías, incluso con una sola pantalla:
        // son los anclajes visuales cuando crece el árbol.
        const groups = new Map();
        for (const entry of catalog.experiences) {
          if (!groups.has(entry.group)) groups.set(entry.group, []);
          groups.get(entry.group).push(entry);
        }
        return [
          ...(catalog.realFlowAction
            ? [node('real', 'Recorrido real', parent.session)] : []),
          ...[...groups.keys()].map(group => node('group', group, parent.session)),
        ];
      }
      if (parent.kind === 'group') return catalog.experiences
        .filter(e => e.group === parent.label)
        .map(e => node('experience', e.label, parent.session, e));
      if (parent.kind === 'experience') return parent.item.states
        .map(s => node('state', s.label, parent.session, parent.item, s));
      return [];
    },
    getTreeItem(item) {
      const state = vscode.TreeItemCollapsibleState;
      const label = item.kind === 'group' ? item.label.toLocaleUpperCase('es') :
        item.label;
      const result = new vscode.TreeItem(label,
        ['state', 'real'].includes(item.kind) ? state.None : state.Collapsed);
      const selected = active.get(item.session.id);
      const activePreview = selected?.mode === 'preview';
      if (item.kind === 'real') {
        result.iconPath = new vscode.ThemeIcon(selected?.mode === 'real'
          ? 'play-circle' : 'circle-outline',
          new vscode.ThemeColor(selected?.mode === 'real'
            ? 'charts.yellow' : 'charts.green'));
        result.tooltip = 'Navegación auténtica: Firebase, cuenta y onboarding real. Puede utilizar IA.';
        result.description = selected?.mode === 'real' ? '● EN EL EMULADOR' : 'Firebase + navegación';
        result.command = {command: 'aiAppsAndroid.realFlow',
          title: 'Abrir recorrido real', arguments: [item.session.id]};
      } else if (item.kind === 'group') {
        const current = activePreview && selected.group === item.label;
        // La carpeta abierta cambia de icono Y de color: visible incluso
        // cuando la rama del árbol está contraída.
        result.iconPath = new vscode.ThemeIcon(current ? 'folder-opened' : 'folder',
          new vscode.ThemeColor(current ? 'charts.yellow' : 'charts.blue'));
        result.contextValue = current ? 'experienceGroupActive' : 'experienceGroup';
        const count = readCatalog(item.session).experiences
          .filter(e => e.group === item.label).length;
        result.description = current
          ? '● EN EL EMULADOR · ' + selected.experience :
            count + (count === 1 ? ' pantalla' : ' pantallas');
        result.tooltip = 'Categoría: ' + item.label;
      } else if (item.kind === 'experience') {
        const current = activePreview && selected.experienceId === item.item.id;
        result.iconPath = new vscode.ThemeIcon(
          current ? 'eye' : 'symbol-file',
          current ? new vscode.ThemeColor('charts.yellow') : undefined);
        if (item.item.states.length === 1) {
          result.collapsibleState = state.None;
          result.command = {command: 'aiAppsAndroid.preview',
            title: 'Abrir experiencia', arguments: [item.session.id,
              item.item.id, item.item.states[0].id]};
        }
        if (current) {
          result.description = '● PANTALLA ABIERTA';
        }
        result.tooltip = item.item.group + ' / ' + item.item.label;
      } else if (item.kind === 'state') {
        result.iconPath = new vscode.ThemeIcon(
          activePreview && selected.experienceId === item.item.id &&
              selected.stateId === item.state.id ? 'circle-filled' : 'circle-outline',
          activePreview && selected.experienceId === item.item.id &&
              selected.stateId === item.state.id
              ? new vscode.ThemeColor('charts.yellow') : undefined);
        result.command = {command: 'aiAppsAndroid.preview', title: 'Abrir estado',
          arguments: [item.session.id, item.item.id, item.state.id]};
        result.description = activePreview &&
            selected.experienceId === item.item.id &&
            selected.stateId === item.state.id
          ? '● ESTADO ACTIVO' : 'Simulación · sin IA';
        result.tooltip = item.item.group + ' / ' + item.item.label + ' / ' +
          item.state.label;
      }
      if (item.kind === 'app') result.description = item.session.serial;
      result.id = [
        'experience', item.kind, item.session.id,
        item.item?.id || item.label, item.state?.id || ''
      ].join(':');
      return result;
    }
  };
  async function open(sessionId, experienceId, stateId) {
    const live = (await service.list()).find(s => s.id === sessionId);
    const catalog = readCatalog(live);
    const exp = catalog?.experiences.find(e => e.id === experienceId);
    const state = exp?.states.find(s => s.id === stateId);
    if (!live || !catalog || !state) throw new Error('Experiencia no registrada.');
    if (!live.deviceReady) throw new Error('Emulador desconectado: ' + live.serial);
    if (!(await service.platform.appPid(live)))
      throw new Error('La aplicación no está ejecutándose.');
    await service.platform.run(service.platform.adb, [
      '-s', live.serial, 'shell', 'am', 'start',
      '-n', catalog.activity,
      '-a', live.packageName + '.DEV_OPEN_EXPERIENCE',
      '-f', '0x20000000',
      '--es', 'experience', exp.id,
      '--es', 'state', state.id
    ]);
    requestedAt.set(live.id, Date.now());
    remember(live, 'preview', exp, state);
    report(live.label + ': ' + exp.label + ' / ' + state.label + ' (simulación)');
  }
  async function openReal(sessionId) {
    const live = (await service.list()).find(s => s.id === sessionId);
    const catalog = readCatalog(live);
    if (!live || !catalog?.realFlowAction) {
      throw new Error('Recorrido real no disponible en esta aplicación.');
    }
    if (!live.deviceReady) throw new Error('Emulador desconectado: ' + live.serial);
    if (!(await service.platform.appPid(live))) {
      throw new Error('La aplicación no está ejecutándose.');
    }
    await service.platform.run(service.platform.adb, [
      '-s', live.serial, 'shell', 'am', 'start',
      '-n', catalog.activity,
      '-a', catalog.realFlowAction,
      '-f', '0x20000000',
    ]);
    requestedAt.set(live.id, Date.now());
    remember(live, 'real');
    report(live.label + ': navegación real solicitada (sin reiniciar Flutter).');
  }
  async function syncActiveLocations(currentSessions) {
    const changes = await Promise.all(currentSessions.map(async session => {
      if (!session.deviceReady || !session.active) return false;
      const catalog = readCatalog(session);
      if (!catalog?.activeLocationFile) return false;
      // Dar tiempo a Flutter a atender el intent, para que una respuesta
      // antigua no desmarque temporalmente la pantalla recién solicitada.
      if (Date.now() - (requestedAt.get(session.id) || 0) < 1500) return false;
      let raw;
      try {
        raw = await service.platform.run(service.platform.adb, [
          '-s', session.serial, 'shell', 'run-as', session.packageName,
          'cat', catalog.activeLocationFile,
        ], {timeout: 3000});
      } catch {
        // APK anterior, app detenida, aún iniciando o sin reporte:
        // conservar la última selección sin afirmar que ha cambiado.
        return false;
      }
      if (typeof raw !== 'string') return false;
      const parts = raw.trim().split(':');
      if (parts.length !== 3) return false;
      const [mode, expId, stateId] = parts;
      let exp, state;
      if (mode === 'preview') {
        exp = catalog.experiences.find(e => e.id === expId);
        state = exp?.states.find(e => e.id === stateId);
        if (!state) return false;
      } else if (mode !== 'real' || expId || stateId ||
          !catalog.realFlowAction) return false;
      const selected = active.get(session.id);
      if (selected?.mode === mode &&
          selected.experienceId === (exp?.id || null) &&
          selected.stateId === (state?.id || null)) return false;
      remember(session, mode, exp, state);
      return true;
    }));
    return changes.some(Boolean);
  }
  function rememberPreview(sessionId, experienceId, stateId) {
    const session = sessions.find(s => s.id === sessionId);
    const exp = readCatalog(session)?.experiences.find(e => e.id === experienceId);
    const state = exp?.states.find(s => s.id === stateId);
    if (session && state) {
      requestedAt.set(session.id, Date.now());
      remember(session, 'preview', exp, state);
    }
  }
  function findTargets() {
    const targets = [];
    for (const session of sessions) {
      if (!session.deviceReady ||
          !session.active) continue;
      const catalog = readCatalog(session);
      if (!catalog) continue;
      if (catalog.realFlowAction) {
        targets.push({label: 'Recorrido real', description: session.label,
          detail: 'Firebase y navegación auténtica',
          sessionId: session.id, mode: 'real'});
      }
      for (const exp of catalog.experiences) {
        for (const state of exp.states) {
          targets.push({label: exp.label + ' / ' + state.label,
            description: session.label + ' · ' + exp.group,
            detail: 'Vista de desarrollo · simulación sin IA',
            sessionId: session.id, mode: 'preview',
            experienceId: exp.id, stateId: state.id});
        }
      }
    }
    return targets;
  }
  function catalogSignature(session) {
    if (!session?.projectPath || session.kind === 'external') return null;
    try {
      const info = fs.statSync(path.join(session.projectPath, CATALOG));
      return [info.mtimeMs, info.size];
    } catch (error) {
      if (error.code === 'ENOENT') return null;
      throw error;
    }
  }

  return {
    provider,
    refresh(next) {
      sessions = next;
      // Los datos de ejecución del emulador no alteran el catálogo. Solo
      // reaccionar ante cambios reales en sus entradas y archivos.
      const snapshot = JSON.stringify(next.map(s => [
        s.id, s.label, s.projectPath, s.packageName,
        catalogSignature(s),
      ]));
      if (snapshot === lastCatalogSnapshot) return false;
      lastCatalogSnapshot = snapshot;
      return true;
    },
    open,
    openReal,
    syncActiveLocations,
    rememberPreview,
    findTargets,
    activeLocation: () => lastLocation,
  };
}
module.exports = {readCatalog,createExperienceExplorer};

