'use strict';

const fs = require('node:fs');
const path = require('node:path');
const IMAGE = /\.(?:png|jpe?g|webp)$/i;
const UNOWNED = 'No se puede eliminar con seguridad: falta registrar el bloque visual de esta imagen. No se ha borrado nada.';

function assertAsset(projectPath, asset) {
  if (!projectPath || typeof asset !== 'string' ||
      !/^assets\/[a-zA-Z0-9_./-]+$/.test(asset) ||
      !IMAGE.test(asset) || asset.split('/').includes('..')) {
    throw new Error('Ruta de recurso no válida.');
  }
  const project = fs.realpathSync(projectPath);
  const target = path.resolve(project, ...asset.split('/'));
  if (!target.startsWith(project + path.sep)) {
    throw new Error('El recurso queda fuera de la aplicación.');
  }
  const info = fs.lstatSync(target);
  if (!info.isFile() || info.isSymbolicLink() ||
      fs.realpathSync(target) !== target) {
    throw new Error('Solo se admiten imágenes reales de la aplicación.');
  }
  return {project, target};
}

function walkDart(dir, paths = []) {
  if (!fs.existsSync(dir)) return paths;
  for (const item of fs.readdirSync(dir, {withFileTypes: true})) {
    if (item.isSymbolicLink() || item.name.startsWith('.')) continue;
    const filename = path.join(dir, item.name);
    if (item.isDirectory()) walkDart(filename, paths);
    else if (item.isFile() && item.name.endsWith('.dart')) paths.push(filename);
  }
  return paths;
}

function refersTo(text, asset) {
  return text.includes("'" + asset + "'") || text.includes('"' + asset + '"');
}

/// Only removes a full comma-terminated widget expression annotated with
/// // ai-apps:visual:start assets/example/image.png
/// Image.asset('assets/example/image.png'),
/// // ai-apps:visual:end assets/example/image.png
function planAssetRemoval(projectPath, asset) {
  const {project, target} = assertAsset(projectPath, asset);
  const startTag = '// ai-apps:visual:start ' + asset;
  const endTag = '// ai-apps:visual:end ' + asset;
  const matches = [];
  for (const filename of walkDart(path.join(project, 'lib'))) {
    const source = fs.readFileSync(filename, 'utf8');
    const hasRef = refersTo(source, asset);
    const hasMarker = source.includes(startTag) || source.includes(endTag);
    if (!hasRef && !hasMarker) continue;
    if (source.split(startTag).length !== 2 ||
        source.split(endTag).length !== 2) throw new Error(UNOWNED);
    const start = source.indexOf(startTag);
    const end = source.indexOf(endTag);
    if (start === -1 || end <= start) throw new Error(UNOWNED);
    const lineStart = source.lastIndexOf('\n', start - 1) + 1;
    if (!/^[ \t]*$/.test(source.slice(lineStart, start))) {
      throw new Error(UNOWNED);
    }
    const endNewline = source.indexOf('\n', end);
    const after = endNewline === -1 ? source.length : endNewline + 1;
    const widget = source.slice(start + startTag.length, end);
    if (!refersTo(widget, asset) || !/,\s*$/.test(widget)) {
      throw new Error(UNOWNED);
    }
    const updated = source.slice(0, lineStart) + source.slice(after);
    if (refersTo(updated, asset)) throw new Error(UNOWNED);
    matches.push({sourcePath: filename, start: lineStart, end: after,
      original: source, updated});
  }
  if (matches.length !== 1) throw new Error(UNOWNED);
  return {asset, filePath: target, ...matches[0]};
}

function isValidImage(data, extension) {
  if (!Buffer.isBuffer(data) || data.length < 12) return false;
  const type = extension.toLowerCase();
  if (type === '.png') return data.subarray(0, 8).equals(
    Buffer.from([137,80,78,71,13,10,26,10]));
  if (type === '.jpg' || type === '.jpeg') return data[0] === 255 &&
    data[1] === 216 && data[2] === 255;
  if (type === '.webp') return data.toString('ascii',0,4) === 'RIFF' &&
    data.toString('ascii',8,12) === 'WEBP';
  return false;
}

module.exports = {assertAsset, planAssetRemoval, isValidImage};

