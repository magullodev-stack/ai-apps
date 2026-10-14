'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { assertAsset, planAssetRemoval, isValidImage } = require('./asset-actions.cjs');

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ai-apps-visual-action-'));
  fs.mkdirSync(path.join(root,'assets','auth'), {recursive:true});
  fs.mkdirSync(path.join(root,'lib','app'), {recursive:true});
  const asset='assets/auth/Stars.png';
  const image=path.join(root,'assets','auth','Stars.png');
  const dart=path.join(root,'lib','app','auth.dart');
  fs.writeFileSync(image,Buffer.from([137,80,78,71,13,10,26,10,0,0,0,0]));
  const source=[
    'Stack(children: [',
    '  // ai-apps:visual:start assets/auth/Stars.png',
    '  Image.asset("assets/auth/Stars.png"),',
    '  // ai-apps:visual:end assets/auth/Stars.png',
    '  const Text("Conservado"),',
    ']);',
    ''
  ].join('\n');
  fs.writeFileSync(dart,source);
  return {root,asset,image,dart,source};
}

function main() {
  const {root,asset,image,dart,source}=fixture();
  try {
    const plan=planAssetRemoval(root,asset);
    assert.equal(plan.filePath,image);
    assert.equal(plan.sourcePath,dart);
    assert.ok(!plan.updated.includes('Image.asset'));
    assert.ok(plan.updated.includes('Conservado'));
    assert.equal(fs.readFileSync(dart,'utf8'),source,
      'Planning cannot modify Dart before user confirmation');
    assert.ok(fs.existsSync(image),'Planning cannot delete assets');
    assert.throws(()=>assertAsset(root,'../secret.png'),/no válida/);
    assert.throws(()=>assertAsset(root,'assets/auth/../Stars.png'),/no válida/);

    fs.writeFileSync(dart,source.replace(
      '  const Text("Conservado"),',
      '  const Text("Conservado"),\n  Image.asset("assets/auth/Stars.png"),'));
    assert.throws(()=>planAssetRemoval(root,asset),/No se puede eliminar/);
    fs.writeFileSync(dart,source.replace(
      '// ai-apps:visual:start assets/auth/Stars.png','// sin marca'));
    assert.throws(()=>planAssetRemoval(root,asset),/No se puede eliminar/);
    fs.writeFileSync(dart,source);
    const other=path.join(root,'lib','app','other.dart');
    fs.writeFileSync(other,'Image.asset("assets/auth/Stars.png");\n');
    assert.throws(()=>planAssetRemoval(root,asset),/No se puede eliminar/);
    fs.unlinkSync(other);
    assert.equal(planAssetRemoval(root,asset).updated,plan.updated);
    assert.equal(isValidImage(fs.readFileSync(image),'.png'),true);
    assert.equal(isValidImage(Buffer.from('not an image'),'.png'),false);
    assert.equal(isValidImage(Buffer.from('RIFFxxxxWEBP'),'.webp'),true);
    console.log('PASS: borrado planificado seguro, referencias únicas y PNG válido');
  } finally {
    fs.rmSync(root,{recursive:true,force:true});
  }
}
main();

