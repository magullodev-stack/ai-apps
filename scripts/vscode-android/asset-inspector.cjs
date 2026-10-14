'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { readCatalog } = require('./explorer.cjs');

const IMAGE = /\.(?:png|jpe?g|webp)$/i;
const MAX_DEPTH = 12;

function listVisualAssets(projectPath) {
  if (!projectPath || !fs.existsSync(path.join(projectPath, 'pubspec.yaml'))) return [];
  const root = path.join(projectPath, 'assets');
  if (!fs.existsSync(root)) return [];
  const found = [];
  function visit(folder, depth) {
    if (depth > MAX_DEPTH) return;
    for (const entry of fs.readdirSync(folder, { withFileTypes: true })) {
      if (entry.name.startsWith('.') || entry.isSymbolicLink()) continue;
      const file = path.join(folder, entry.name);
      if (entry.isDirectory()) visit(file, depth + 1);
      else if (entry.isFile() && IMAGE.test(entry.name)) {
        found.push(path.relative(projectPath, file).replace(/\\/g, '/'));
      }
    }
  }
  visit(root, 0);
  return found.sort((a, b) => a.localeCompare(b));
}

function createVisualAssetInspector(vscode, service, report) {
  const hiddenBySession = new Map();

  const root = session => ({ kind: 'assetsRoot', session });
  const folder = (session, folderPath) =>
    ({ kind: 'assetsFolder', session, folderPath });
  const image = (session, asset) =>
    ({ kind: 'visualAsset', session, asset });

  function getChildren(item) {
    const images = listVisualAssets(item.session.projectPath);
    const prefix = item.kind === 'assetsRoot' ? 'assets/' :
      item.folderPath + '/';
    const directories = new Set(), resources = [];
    for (const asset of images) {
      if (!asset.startsWith(prefix)) continue;
      const remaining = asset.slice(prefix.length);
      const slash = remaining.indexOf('/');
      if (slash !== -1) directories.add(prefix + remaining.slice(0, slash));
      else resources.push(image(item.session, asset));
    }
    return [
      ...[...directories].sort().map(p => folder(item.session, p)),
      ...resources,
    ];
  }

  function getTreeItem(item) {
    const expand = vscode.TreeItemCollapsibleState;
    if (item.kind === 'assetsRoot') {
      const result = new vscode.TreeItem('Capas e imágenes', expand.Collapsed);
      result.id = 'visual-assets:' + item.session.id;
      result.iconPath = new vscode.ThemeIcon('layers');
      result.tooltip = 'Oculta o muestra imágenes en la aplicación de desarrollo. Sin borrar PNG.';
      return result;
    }
    if (item.kind === 'assetsFolder') {
      const result = new vscode.TreeItem(
        path.posix.basename(item.folderPath), expand.Collapsed);
      result.id = 'visual-assets:' + item.session.id + ':' + item.folderPath;
      result.iconPath = new vscode.ThemeIcon('folder');
      return result;
    }
    const hidden = hiddenBySession.get(item.session.id)?.has(item.asset) || false;
    const result = new vscode.TreeItem(
      path.posix.basename(item.asset), expand.None);
    result.id = 'visual-assets:' + item.session.id + ':' + item.asset;
    result.iconPath = new vscode.ThemeIcon(hidden ? 'eye-closed' : 'eye');
    result.description = hidden ? 'Oculta' : 'Visible';
    result.tooltip = item.asset + ' · clic para ' + (hidden ? 'mostrar' : 'ocultar');
    result.command = { command: 'aiAppsAndroid.toggleVisualAsset',
      title: hidden ? 'Mostrar imagen' : 'Ocultar imagen',
      arguments: [item.session.id, item.asset] };
    return result;
  }

  async function toggle(sessionId, asset) {
    const session = (await service.list()).find(s => s.id === sessionId);
    const catalog = session && readCatalog(session);
    if (!catalog || !session.deviceReady ||
        !listVisualAssets(session.projectPath).includes(asset)) {
      throw new Error('Recurso visual no disponible para esta aplicación.');
    }
    if (!(await service.platform.appPid(session))) {
      throw new Error('La aplicación debe estar ejecutándose en el emulador.');
    }
    const hidden = hiddenBySession.get(sessionId) || new Set();
    const visible = hidden.has(asset);
    await service.platform.run(service.platform.adb, [
      '-s', session.serial, 'shell', 'am', 'start',
      '-n', catalog.activity,
      '-a', session.packageName + '.DEV_ASSET_VISIBILITY',
      '-f', '0x20000000',
      '--es', 'asset', asset,
      '--ez', 'visible', String(visible),
    ]);
    if (visible) hidden.delete(asset);
    else hidden.add(asset);
    hiddenBySession.set(sessionId, hidden);
    report((visible ? 'Mostrada: ' : 'Oculta: ') + asset);
    return visible;
  }
  return { root, getChildren, getTreeItem, toggle, listVisualAssets };
}

module.exports = { listVisualAssets, createVisualAssetInspector };

