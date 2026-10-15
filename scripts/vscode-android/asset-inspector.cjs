'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { readCatalog } = require('./explorer.cjs');
const { assertAsset, planAssetRemoval, isValidImage } = require('./asset-actions.cjs');
const { referencedAssets, sourceSignature } = require('./visual-source-index.cjs');
const { planVisualRenames } = require('./visual-renames.cjs');

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
  const sourceCache = new Map();
  let lastSnapshot;
  let renamingInInspector = false;

  function sources(session) {
    const signature = JSON.stringify(sourceSignature(session.projectPath));
    const cache = sourceCache.get(session.projectPath);
    if (cache?.signature === signature) return cache.references;
    const references = referencedAssets(session.projectPath);
    sourceCache.set(session.projectPath, {signature, references});
    return references;
  }

  // No dependency on Muondia: detect changes in every active Flutter app.
  // The extension polls every five seconds as a fallback for external
  // moves, git sync and file operations without VS Code rename events.
  function refresh(sessions) {
    const snapshot = JSON.stringify(sessions
      .filter(session => session.kind !== 'external' && session.projectPath)
      .map(session => [session.id, listVisualAssets(session.projectPath),
        sourceSignature(session.projectPath)]));
    if (snapshot === lastSnapshot) return false;
    lastSnapshot = snapshot;
    return true;
  }

  const image = (session, asset) =>
    ({ kind: 'visualAsset', session, asset });

  // El catálogo de experiencias ya es el árbol de UI. Cada experiencia
  // posee sus recursos: no se crea una segunda carpeta "Capas e imágenes".
  function forExperience(session, experience) {
    const directories = experience?.assetDirectories || [];
    if (!directories.length) return [];
    const used = sources(session);
    return listVisualAssets(session.projectPath)
      .filter(asset => directories.some(dir => asset.startsWith(dir + '/')))
      .map(asset => ({...image(session, asset), placed: used.has(asset)}));
  }

  function getTreeItem(item) {
    const expand = vscode.TreeItemCollapsibleState;
    const pending = !item.placed;
    const hidden = !pending &&
      (hiddenBySession.get(item.session.id)?.has(item.asset) || false);
    const result = new vscode.TreeItem(
      path.posix.basename(item.asset), expand.None);
    result.id = 'visual-assets:' + item.session.id + ':' + item.asset;
    result.iconPath = new vscode.ThemeIcon('file-media');
    result.contextValue = pending ? 'visualAssetPending' :
      hidden ? 'visualAssetHidden' : 'visualAssetVisible';
    result.description = pending ? '⏳ Pendiente' : hidden ? 'Oculta' : '';
    result.tooltip = pending
      ? item.asset + ' · No hay referencia Dart directa: pendiente de colocar'
      : item.asset + ' · ojo para ' + (hidden ? 'mostrar' : 'ocultar') +
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
    if (!sources(session).has(asset)) {
      throw new Error('Imagen pendiente de colocar: todavía no puede ocultarse.');
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
      throw new Error('Selecciona una imagen dentro de su pantalla.');
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

  function pendingInfo(supplied) {
    const entry = resolveNode(supplied);
    vscode.window.showInformationMessage(
      '⏳ ' + path.basename(entry.asset) +
      ' está en el repositorio, pero no tiene una referencia Dart directa. ' +
      'Añádela al widget de esta pantalla para activar el ojo.');
  }

  async function renameImage(supplied) {
    const entry = resolveNode(supplied);
    const {target} = assertAsset(entry.session.projectPath, entry.asset);
    const originalName = path.basename(target);
    const name = await vscode.window.showInputBox({
      title: 'Cambiar nombre de imagen', value: originalName,
      prompt: 'Se actualizarán sus referencias Dart y pubspec.yaml.',
      validateInput: text => !text || !/^[^/\\]+$/.test(text) ||
        text.startsWith('.') || path.extname(text).toLowerCase() !==
          path.extname(originalName).toLowerCase()
        ? 'Usa un nombre de imagen válido sin cambiar su formato.' : undefined,
    });
    if (!name || name === originalName) return false;
    const next = path.join(path.dirname(target), name);
    if (fs.existsSync(next)) {
      throw new Error('Ya existe una imagen llamada ' + name);
    }
    const from = vscode.Uri.file(target);
    const dest = vscode.Uri.file(next);
    const plans = planVisualRenames(entry.session,
      [{oldUri:from,newUri:dest}]);
    const edit = new vscode.WorkspaceEdit();
    const documents = [];
    for (const plan of plans) {
      const uri = vscode.Uri.file(plan.filename);
      const doc = await vscode.workspace.openTextDocument(uri);
      if (doc.isDirty || doc.getText() !== plan.original) {
        throw new Error('Guarda los cambios pendientes en ' +
          path.basename(plan.filename) + ' antes de renombrar.');
      }
      edit.replace(uri, new vscode.Range(
        doc.positionAt(0), doc.positionAt(plan.original.length)),
        plan.updated);
      documents.push(doc);
    }
    edit.renameFile(from, dest, {overwrite:false});
    renamingInInspector = true;
    try {
      if (!await vscode.workspace.applyEdit(edit)) {
        throw new Error('No se pudo renombrar la imagen y sus referencias.');
      }
    } finally {
      renamingInInspector = false;
    }
    for (const doc of documents) {
      if (!await doc.save()) {
        throw new Error('Renombrado aplicado; guarda los cambios de Dart y pubspec.');
      }
    }
    hiddenBySession.get(entry.session.id)?.delete(entry.asset);
    sourceCache.delete(entry.session.projectPath);
    report('Imagen renombrada: ' + entry.asset + ' → ' +
      path.posix.dirname(entry.asset) + '/' + name);
    return true;
  }

  async function deleteImage(supplied) {
    const entry = resolveNode(supplied);
    const pending = !sources(entry.session).has(entry.asset);
    if (pending) {
      // No Dart reference to remove. Keep this operation separate from
      // the source-editing flow and require explicit user confirmation.
      const {target} = assertAsset(entry.session.projectPath, entry.asset);
      const ok = await vscode.window.showWarningMessage(
        '¿Eliminar la imagen pendiente ' + path.basename(target) + '?',
        {modal: true, detail: 'No se ha encontrado una referencia Dart directa. ' +
          'Solo se moverá el PNG a la papelera; el código no se modificará. ' +
          'Si la imagen se usa mediante una ruta dinámica, revísala primero.'},
        'Eliminar PNG pendiente');
      if (ok !== 'Eliminar PNG pendiente') return false;
      assertAsset(entry.session.projectPath, entry.asset);
      const edit = new vscode.WorkspaceEdit();
      edit.deleteFile(vscode.Uri.file(target), {useTrash:true});
      if (!await vscode.workspace.applyEdit(edit)) {
        throw new Error('VS Code no pudo borrar la imagen pendiente.');
      }
    } else {
      // A placed image can only be removed with a verified, owned Dart block.
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
    }
    hiddenBySession.get(entry.session.id)?.delete(entry.asset);
    report('Imagen eliminada: ' + entry.asset);
    return true;
  }

  return { forExperience, getTreeItem, toggle, resolveNode, refresh,
    replaceImage, deleteImage, renameImage, pendingInfo,
    isManagedRename: () => renamingInInspector, listVisualAssets };
}

module.exports = { listVisualAssets, createVisualAssetInspector };

