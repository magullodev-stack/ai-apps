'use strict';

const fs = require('node:fs');
const path = require('node:path');
const IMAGE = /\.(?:png|jpe?g|webp)$/i;
const UNSAFE = 'No se puede eliminar la imagen sin dejar dependencias. Registra el código y las pruebas asociados o retira sus referencias antes de borrar. No se ha modificado nada.';

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

// All application Dart, tests, tool scripts and documentation; never assets,
// build outputs, symlinks, dependencies or generated caches.
function sourceFiles(project) {
  const roots = ['lib', 'test', 'integration_test', 'tool', 'docs'];
  const results = [];
  const types = /\.(?:dart|md|yaml|yml|json)$/i;
  function visit(folder, depth) {
    if (!fs.existsSync(folder) || depth > 24) return;
    for (const item of fs.readdirSync(folder, {withFileTypes:true})) {
      if (item.name.startsWith('.') || item.isSymbolicLink()) continue;
      const full = path.join(folder, item.name);
      if (item.isDirectory()) visit(full, depth+1);
      else if (item.isFile() && types.test(item.name)) {
        if (fs.statSync(full).size > 2*1024*1024) {
          throw new Error('No se puede auditar el archivo grande: ' + full);
        }
        results.push(full);
      }
    }
  }
  for (const root of roots) visit(path.join(project,root),0);
  for (const name of ['README.md','pubspec.yaml']) {
    const filename = path.join(project,name);
    if (fs.existsSync(filename)) results.push(filename);
  }
  return results.sort();
}

// A layer can own multiple standalone fragments (widgets, fields, test
// cases). Each is explicitly delimited by matching, asset-specific markers.
// No arbitrary textual deletion or inferred ownership.
function removeOwned(source,asset) {
  const start = '// ai-apps:visual:start ' + asset;
  const end = '// ai-apps:visual:end ' + asset;
  const lines = source.match(/[^\n]*\n|[^\n]+$/g) || [];
  let open = -1, offset = 0, startOffset = 0;
  const spans = [];
  for (const line of lines) {
    const marker = line.trim();
    if (marker === start) {
      if (open !== -1) throw new Error(UNSAFE);
      open = offset; startOffset = offset + line.length;
    } else if (marker === end) {
      if (open < 0) throw new Error(UNSAFE);
      const fragment = source.slice(startOffset, offset).trim();
      if (!fragment || !/[,;}]$/.test(fragment)) throw new Error(UNSAFE);
      spans.push({start:open,end:offset+line.length,fragment});
      open = -1;
    }
    offset += line.length;
  }
  if (open !== -1 || (source.includes(start) || source.includes(end)) &&
      spans.length === 0) throw new Error(UNSAFE);
  let updated = source;
  for (const span of [...spans].reverse()) {
    updated = updated.slice(0,span.start) + updated.slice(span.end);
  }
  return {spans,updated};
}

function assetReferences(project,asset,changes) {
  const remaining = new Map(changes.map(item=>[item.filename,item.updated]));
  const filename = path.posix.basename(asset);
  for (const file of sourceFiles(project)) {
    const source = remaining.get(file) ?? fs.readFileSync(file,'utf8');
    if (source.includes(asset) || source.includes(filename)) {
      throw new Error(UNSAFE + ' Referencia restante en ' +
        path.relative(project,file));
    }
  }
}

function planAssetRemoval(projectPath,asset) {
  const {project,target} = assertAsset(projectPath,asset);
  const changes = [], fragments = [];
  let containsLayer = false;
  for (const filename of sourceFiles(project)) {
    const original = fs.readFileSync(filename,'utf8');
    const owned = removeOwned(original,asset);
    if (!owned.spans.length) continue;
    if (!filename.endsWith('.dart')) throw new Error(UNSAFE);
    containsLayer ||= filename.startsWith(path.join(project,'lib')+path.sep) &&
      owned.spans.some(item=>item.fragment.includes(asset));
    fragments.push(...owned.spans.map(item=>item.fragment));
    changes.push({filename,original,updated:owned.updated});
  }
  if (!containsLayer) throw new Error(UNSAFE);
  assetReferences(project,asset,changes);

  // A removed widget may refer to a condition such as widget.showStars.
  // If a field/constructor/control still mentions the property, the
  // deletion MUST fail instead of leaving an inert UI overlay behind.
  const properties = new Set(fragments.flatMap(fragment =>
    [...fragment.matchAll(/\bwidget\.([a-zA-Z_]\w*)/g)].map(m=>m[1])));
  const remaining = new Map(changes.map(item=>[item.filename,item.updated]));
  for (const file of sourceFiles(project).filter(x=>x.endsWith('.dart'))) {
    const source = remaining.get(file) ?? fs.readFileSync(file,'utf8');
    for (const property of properties) {
      // Allow _showStars, showStars and widget.showStars variants.
      const pattern = new RegExp('(^|[^\\w])_?' + property + '\\b');
      if (pattern.test(source)) {
        throw new Error(UNSAFE + ' Propiedad aún utilizada: ' + property +
          ' en ' + path.relative(project,file));
      }
    }
  }
  const main = changes.find(x=>x.filename.startsWith(
    path.join(project,'lib')+path.sep));
  return {asset,filePath:target,changes,sourcePath:main.filename,
    original:main.original,updated:main.updated};
}

function planPendingAssetRemoval(projectPath,asset) {
  const {project,target} = assertAsset(projectPath,asset);
  assetReferences(project,asset,[]);
  return {asset,filePath:target};
}

function isValidImage(data,extension) {
  if (!Buffer.isBuffer(data) || data.length < 12) return false;
  const type = extension.toLowerCase();
  if (type === '.png') return data.subarray(0,8).equals(
    Buffer.from([137,80,78,71,13,10,26,10]));
  if (type === '.jpg' || type === '.jpeg') return data[0] === 255 &&
    data[1] === 216 && data[2] === 255;
  if (type === '.webp') return data.toString('ascii',0,4) === 'RIFF' &&
    data.toString('ascii',8,12) === 'WEBP';
  return false;
}

module.exports={assertAsset,sourceFiles,planAssetRemoval,
  planPendingAssetRemoval,isValidImage};

