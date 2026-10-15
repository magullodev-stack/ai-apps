'use strict';

const fs = require('node:fs');
const path = require('node:path');
const {dartFiles} = require('./visual-source-index.cjs');

function posixRelative(projectPath, filename) {
  const rel = path.relative(projectPath, filename).replace(/\\/g, '/');
  if (!rel.startsWith('assets/') || rel.includes('../')) return null;
  return rel;
}

function rewritePaths(input, moves) {
  // Only path-like quoted string literals and declared visual ownership
  // markers are rewritten, not arbitrary substrings of source code.
  let result = input.replace(/(['"])(assets\/[^'"\r\n]+)\1/g,
    (match, quote, asset) => {
      const move = moves.find(item => item.isDirectory
        ? asset === item.old || asset.startsWith(item.old + '/')
        : asset === item.old);
      if (!move) return match;
      return quote + move.new + asset.slice(move.old.length) + quote;
    });
  result = result.replace(/(\/\/ ai-apps:visual:(?:start|end) )(assets\/[^\r\n]+)/g,
    (match, marker, asset) => {
      const move = moves.find(item => item.isDirectory
        ? asset === item.old || asset.startsWith(item.old + '/')
        : asset === item.old);
      return move ? marker + move.new + asset.slice(move.old.length) : match;
    });
  return result;
}

function planVisualRenames(session, renameFiles) {
  if (!session?.projectPath || !fs.existsSync(
      path.join(session.projectPath, 'pubspec.yaml'))) return [];
  const moves = [];
  for (const pair of renameFiles) {
    const oldPath = pair.oldUri.fsPath, newPath = pair.newUri.fsPath;
    const old = posixRelative(session.projectPath, oldPath);
    if (!old) continue;
    const next = posixRelative(session.projectPath, newPath);
    // Only a rename, not a move between UI screens.
    if (!next || path.dirname(oldPath) !== path.dirname(newPath) ||
        !/^[^/\\]+$/.test(path.basename(newPath)) ||
        path.basename(newPath).startsWith('.')) {
      throw new Error('Solo se permite cambiar el nombre dentro de la misma carpeta de recursos.');
    }
    const info = fs.lstatSync(oldPath);
    if (info.isSymbolicLink()) throw new Error('No se pueden renombrar enlaces simbólicos.');
    const isDirectory = info.isDirectory();
    if (!isDirectory && !/\.(png|jpe?g|webp)$/i.test(old)) continue;
    if (!isDirectory && path.extname(old).toLowerCase() !==
        path.extname(next).toLowerCase()) {
      throw new Error('Renombra la imagen sin cambiar su formato.');
    }
    if (fs.existsSync(newPath)) {
      throw new Error('El nombre de destino ya existe: ' + next);
    }
    moves.push({old, new:next, isDirectory});
  }
  if (!moves.length) return [];
  if (moves.length > 1 && moves.some((one,i) =>
      moves.some((two,j) => j !== i &&
        (one.old === two.old || one.old.startsWith(two.old + '/'))))) {
    throw new Error('Renombres de recursos solapados: operación cancelada.');
  }
  const edits = [];
  for (const filename of dartFiles(session.projectPath)) {
    const original = fs.readFileSync(filename, 'utf8');
    const updated = rewritePaths(original, moves);
    if (updated !== original) edits.push({filename, original, updated});
  }

  const catalogFile = path.join(session.projectPath,
    'lib', 'app', 'development', 'experiences.json');
  if (fs.existsSync(catalogFile)) {
    const original = fs.readFileSync(catalogFile, 'utf8');
    const doc = JSON.parse(original);
    let modified = false;
    for (const exp of doc.experiences || []) {
      if (!Array.isArray(exp.assetDirectories)) continue;
      exp.assetDirectories = exp.assetDirectories.map(dir => {
        const move = moves.find(m => m.isDirectory &&
          (dir === m.old || dir.startsWith(m.old + '/')));
        if (!move) return dir;
        modified = true;
        return move.new + dir.slice(move.old.length);
      });
    }
    if (modified) edits.push({filename:catalogFile, original,
      updated:JSON.stringify(doc,null,2) + '\n'});
  }

  const pubspecFile = path.join(session.projectPath, 'pubspec.yaml');
  const yaml = fs.readFileSync(pubspecFile, 'utf8');
  // pubspec asset declarations are usually YAML paths without quotes.
  // Keep indentation/comments intact and only alter asset list entries.
  const newYaml = rewritePaths(yaml, moves).replace(
    /(^[ \t]*- [ \t]*)(assets\/[^\s#]+)([ \t]*(?:#.*)?)$/gm,
    (line, prefix, resource, suffix) => {
      const move = moves.find(item => item.isDirectory
        ? resource === item.old || resource.startsWith(item.old + '/')
        : resource === item.old);
      return move
        ? prefix + move.new + resource.slice(move.old.length) + suffix
        : line;
    });
  if (yaml !== newYaml) edits.push({filename:pubspecFile,
    original:yaml, updated:newYaml});
  return edits;
}

module.exports = {planVisualRenames, rewritePaths};

