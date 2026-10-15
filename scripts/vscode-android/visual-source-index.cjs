'use strict';

const fs = require('node:fs');
const path = require('node:path');

const IMAGE = /\.(?:png|jpe?g|webp)$/i;
const ASSET_LITERAL = /^assets\/[^\\\r\n'"]+\.(?:png|jpe?g|webp)$/i;
const MAX_DEPTH = 20;

function dartFiles(projectPath) {
  const found = [];
  const lib = path.join(projectPath, 'lib');
  if (!fs.existsSync(lib)) return found;
  function visit(folder, depth) {
    if (depth > MAX_DEPTH) return;
    for (const item of fs.readdirSync(folder, {withFileTypes: true})) {
      if (item.isSymbolicLink() || item.name.startsWith('.')) continue;
      const full = path.join(folder, item.name);
      if (item.isDirectory()) visit(full, depth + 1);
      else if (item.isFile() && item.name.endsWith('.dart')) found.push(full);
    }
  }
  visit(lib, 0);
  return found.sort();
}

// Read literal strings, ignoring line and block comments. A filename in a
// commented-out widget is NOT proof that the image is placed on the screen.
// Dynamic paths cannot be established from source text and stay "pending".
function dartImageLiterals(source) {
  const found = new Set();
  let i = 0;
  while (i < source.length) {
    const ch = source[i], next = source[i + 1];
    if (ch === '/' && next === '/') {
      i = source.indexOf('\n', i + 2);
      if (i === -1) break;
      continue;
    }
    if (ch === '/' && next === '*') {
      i += 2;
      let depth = 1;
      while (i < source.length && depth) {
        if (source[i] === '/' && source[i + 1] === '*') {
          depth++; i += 2;
        } else if (source[i] === '*' && source[i + 1] === '/') {
          depth--; i += 2;
        } else i++;
      }
      continue;
    }
    if (ch !== "'" && ch !== '"') { i++; continue; }
    const quote = ch;
    const triple = source.slice(i, i + 3) === quote.repeat(3);
    const raw = i > 0 && /[rR]/.test(source[i - 1]) &&
      (i === 1 || !/[\w$]/.test(source[i - 2]));
    i += triple ? 3 : 1;
    let value = '';
    while (i < source.length) {
      if (source.slice(i, i + (triple ? 3 : 1)) ===
          quote.repeat(triple ? 3 : 1)) {
        i += triple ? 3 : 1;
        break;
      }
      if (!raw && source[i] === '\\') {
        // Escapes are not direct file paths; skip the escaped sequence.
        i += 2; value = '\0'; continue;
      }
      value += source[i++];
    }
    if (ASSET_LITERAL.test(value) && !value.includes('..')) {
      found.add(value.replace(/\\/g, '/'));
    }
  }
  return found;
}

function referencedAssets(projectPath) {
  const refs = new Set();
  for (const filename of dartFiles(projectPath)) {
    for (const asset of dartImageLiterals(fs.readFileSync(filename, 'utf8'))) {
      refs.add(asset);
    }
  }
  return refs;
}

function sourceSignature(projectPath) {
  return dartFiles(projectPath).map(file => {
    const stat = fs.statSync(file);
    return [path.relative(projectPath, file).replace(/\\/g, '/'),
      stat.mtimeMs, stat.size];
  });
}

module.exports = {dartFiles, dartImageLiterals, referencedAssets, sourceSignature,
  IMAGE};

