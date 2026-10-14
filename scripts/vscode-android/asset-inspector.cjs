'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { readCatalog } = require('./explorer.cjs');
const { assertAsset, planAssetRemoval, isValidImage } = require('./asset-actions.cjs');

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
    result.iconPath = new vscode.ThemeIcon('file-media');
    result.contextValue = hidden ? 'visualAssetHidden' : 'visualAssetVisible';
    result.description = hidden ? 'Oculta' : '';
    result.tooltip = item.asset + ' · ojo para ' + (hidden ? 'mostrar' : 'ocultar') +
      ' · botón derecho para sustituir o eliminar';
    result.command = {
      command: 'vscode.open', title: 'Abrir imagen',
      arguments: [vscode.Uri.file(path.join(item.session.projectPath,
        ...item.asset.split('/')))],
    };
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
  function resolveNode(supplied) {
    const entry = supplied?.visualAssetNode || supplied;
    if (entry?.kind !== 'visualAsset' || !entry.session?.id ||
        typeof entry.asset !== 'string') {
      throw new Error('Selecciona una imagen en Capas e imágenes.');
    }
    return entry;
  }

  async function replaceImage(supplied) {
    const entry = resolveNode(supplied);
    const { target } = assertAsset(entry.session.projectPath, entry.asset);
    const selected = await vscode.window.showOpenDialog({
      canSelectFiles: true, canSelectFolders: false, canSelectMany: false,
      openLabel: 'Sustituir imagen',
      filters: { Imágenes: ['png', 'jpg', 'jpeg', 'webp'] },
    });
    if (!selected?.[0]) return false;
    const replacement = selected[0].fsPath;
    if (path.resolve(replacement) === target) return false;
    if (path.extname(replacement).toLowerCase() !==
        path.extname(target).toLowerCase()) {
      throw new Error('Elige una imagen del mismo formato.');
    }
    const bytes = fs.readFileSync(replacement);
    if (bytes.length > 50 * 1024 * 1024 ||
        !isValidImage(bytes, path.extname(target))) {
      throw new Error('La imagen seleccionada no es válida o es demasiado grande.');
    }
    const ok = await vscode.window.showWarningMessage(
      '¿Sustituir ' + path.basename(target) + '?',
      {modal: true, detail: 'Se conserva el nombre de archivo y el código Dart. ' +
        'Puedes recuperar la imagen anterior desde Git.'}, 'Sustituir imagen');
    if (ok !== 'Sustituir imagen') return false;
    assertAsset(entry.session.projectPath, entry.asset);
    await vscode.workspace.fs.writeFile(vscode.Uri.file(target), bytes);
    report('Imagen sustituida: ' + entry.asset);
    return true;
  }

  async function deleteImage(supplied) {
    const entry = resolveNode(supplied);
    // Primero analizar todo el código y comprobar que la capa es exclusiva.
    const plan = planAssetRemoval(entry.session.projectPath, entry.asset);
    const uri = vscode.Uri.file(plan.sourcePath);
    const doc = await vscode.workspace.openTextDocument(uri);
    if (doc.isDirty || doc.getText() !== plan.original) {
      throw new Error('El código Dart tiene cambios sin guardar. Guárdalos primero.');
    }
    const ok = await vscode.window.showWarningMessage(
      '¿Eliminar ' + path.basename(plan.filePath) + ' y su capa visual?',
      {modal: true, detail: 'Se eliminará el widget de ' +
        path.relative(entry.session.projectPath, plan.sourcePath) +
        ' y el PNG se moverá a la papelera. Puedes deshacerlo con VS Code.'},
      'Eliminar imagen y capa');
    if (ok !== 'Eliminar imagen y capa') return false;
    if (doc.isDirty || doc.getText() !== plan.original ||
        fs.readFileSync(plan.sourcePath, 'utf8') !== plan.original) {
      throw new Error('El código cambió durante la confirmación. Cancelado.');
    }
    assertAsset(entry.session.projectPath, entry.asset);
    const edit = new vscode.WorkspaceEdit();
    edit.delete(uri, new vscode.Range(
      doc.positionAt(plan.start), doc.positionAt(plan.end)));
    edit.deleteFile(vscode.Uri.file(plan.filePath), {useTrash: true});
    if (!await vscode.workspace.applyEdit(edit)) {
      throw new Error('VS Code no pudo aplicar la eliminación.');
    }
    if (!await doc.save()) {
      throw new Error('Dart fue modificado, pero no se pudo guardar. Guárdalo manualmente.');
    }
    hiddenBySession.get(entry.session.id)?.delete(entry.asset);
    report('Recurso y capa eliminados: ' + entry.asset);
    return true;
  }

  return { root, getChildren, getTreeItem, toggle, resolveNode,
    replaceImage, deleteImage, listVisualAssets };
}

module.exports = { listVisualAssets, createVisualAssetInspector };

