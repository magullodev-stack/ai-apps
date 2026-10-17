'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {dartImageLiterals, referencedAssets, sourceSignature} =
  require('./visual-source-index.cjs');

const sample = [
  "// Image.asset('assets/auth/Comment.png');",
  "/* Image.asset('assets/auth/Block.png'); */",
  "Image.asset('assets/auth/Visible.png');",
  "const a = AssetImage(\"assets/auth/Other.webp\");",
  "_movingLayer(asset: 'assets/auth/Stars.png'),",
  "final x = 'assets/auth/' + 'Dynamic.png';",
  "final raw = r'assets/auth/Raw.png';",
].join('\n');
assert.deepEqual([...dartImageLiterals(sample)].sort(), [
  'assets/auth/Other.webp','assets/auth/Raw.png',
  'assets/auth/Stars.png','assets/auth/Visible.png',
], 'Only direct, uncommented Dart strings count as placed');

const root = fs.mkdtempSync(path.join(os.tmpdir(),'ai-apps-visual-refs-'));
try {
  const lib = path.join(root,'lib','app');
  fs.mkdirSync(lib,{recursive:true});
  fs.writeFileSync(path.join(lib,'auth.dart'),sample);
  assert.deepEqual([...referencedAssets(root)].sort(),
    [...dartImageLiterals(sample)].sort());
  assert.equal(sourceSignature(root).length,1);
  fs.writeFileSync(path.join(lib,'home.dart'),
    "Image.asset('assets/home/Home.png');\n");
  assert.ok(referencedAssets(root).has('assets/home/Home.png'));
  fs.renameSync(path.join(lib,'home.dart'),path.join(lib,'home-new.dart'));
  assert.ok(sourceSignature(root).some(([file])=>file.endsWith('home-new.dart')));
} finally {fs.rmSync(root,{recursive:true,force:true});}
// La ruta de la imagen en el test se selecciona dinamicamente en Flutter,
// pero el mapa de imagenes registra cada archivo de forma literal.
const muondia = path.resolve(__dirname, '../../apps/muondia');
const pivots = referencedAssets(muondia);
const pivotImageRefs = [...pivots].filter(asset =>
  /^assets\/Pivotes\/P\d\d - .+\.png$/.test(asset));
assert.equal(pivotImageRefs.length, 20,
  'Los 20 PNG de pivotes deben reconocerse como colocados por el indice estatico');
assert.ok(pivots.has('assets/Pivotes/P01 - Arquitectura.png'));
assert.ok(pivots.has('assets/Pivotes/P08 - Física.png'));
assert.ok(pivots.has('assets/Pivotes/P20 - Sociología.png'));

console.log('PASS: detección de imágenes colocadas, comentarios y archivos Dart');

