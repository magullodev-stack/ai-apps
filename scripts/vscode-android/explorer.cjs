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
  const ids = new Set();
  // Cada carpeta visual tiene una sola pantalla propietaria.
  // No pueden solaparse: ocultar, sustituir o eliminar un recurso no
  // debe afectar accidentalmente a otra experiencia.
  const assetDirectories = [];
  const directoryPattern = /^assets(?:\/[a-zA-Z0-9_-]+)+$/;
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
          item.assetDirectories.some(dir => typeof dir !== 'string' ||
            !directoryPattern.test(dir)))) {
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
  const node = (kind, label, session, item, state) => ({kind,label,session,item,state});
  // Los cambios del explorador se notifican desde el árbol principal de
  // AI-APPS Android. Este proveedor interno no registra un emitter propio.
  const provider = {
    getChildren(parent) {
      if (!parent) return sessions.filter(s => readCatalog(s))
        .map(s => node('app', s.label, s));
      const catalog = readCatalog(parent.session);
      if (!catalog) return [];
      if (parent.kind === 'app') {
        // Evitar carpetas sin utilidad: los grupos con una sola experiencia
        // se muestran directamente (Auth y Home en Muondia).
        const groups = new Map();
        for (const entry of catalog.experiences) {
          if (!groups.has(entry.group)) groups.set(entry.group, []);
          groups.get(entry.group).push(entry);
        }
        return [...groups.entries()].flatMap(([group, entries]) =>
          entries.length === 1
            ? [node('experience', entries[0].label, parent.session, entries[0])]
            : [node('group', group, parent.session)]);
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
      const result = new vscode.TreeItem(item.label,
        item.kind === 'state' ? state.None : state.Collapsed);
      if (item.kind === 'experience' && item.item.states.length === 1) {
        result.collapsibleState = state.None;
        result.command = { command: 'aiAppsAndroid.preview', title: 'Abrir experiencia',
          arguments: [item.session.id, item.item.id, item.item.states[0].id] };
      } else if (item.kind === 'state') {
        result.command = { command: 'aiAppsAndroid.preview', title: 'Abrir estado',
          arguments: [item.session.id, item.item.id, item.state.id] };
        result.description = 'Simulación · sin IA';
      }
      if (item.kind === 'app') result.description = item.session.serial;
      // IDs estables para conservar los nodos desplegados entre refrescos.
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
    report(live.label + ': ' + exp.label + ' / ' + state.label + ' (simulación)');
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
  };
}
module.exports = {readCatalog,createExperienceExplorer};

