'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { assertAsset, planAssetRemoval, planPendingAssetRemoval, isValidImage } = require('./asset-actions.cjs');

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

    // An owned UI widget is not enough: unused properties, controls and
    // tests must be removed too, otherwise the action fails BEFORE editing.
    const conditional=source.replace(
      '  Image.asset("assets/auth/Stars.png"),',
      '  if (widget.showStars) Image.asset("assets/auth/Stars.png"),')
      .replace('Stack(children: [','final bool showStars;\nStack(children: [');
    fs.writeFileSync(dart,conditional);
    assert.throws(()=>planAssetRemoval(root,asset),/showStars/,
      'Orphan widget property must block deletion');
    const annotated=conditional.replace('final bool showStars;',
      '// ai-apps:visual:start assets/auth/Stars.png\n' +
      'final bool showStars;\n' +
      '// ai-apps:visual:end assets/auth/Stars.png');
    fs.writeFileSync(dart,annotated);
    assert.equal(planAssetRemoval(root,asset).changes.length,1,
      'Multiple owned source fragments are deleted together');
    assert.ok(!planAssetRemoval(root,asset).updated.includes('showStars'));

    fs.mkdirSync(path.join(root,'test'),{recursive:true});
    const fixtureTest=path.join(root,'test','auth_test.dart');
    fs.writeFileSync(fixtureTest,
      "test('asset', () { expect('assets/auth/Stars.png', isNotEmpty); });\n");
    assert.throws(()=>planAssetRemoval(root,asset),/auth_test.dart/,
      'Stale widget tests must block deletion');
    fs.writeFileSync(fixtureTest,[
      '// ai-apps:visual:start assets/auth/Stars.png',
      "test('asset', () { expect('assets/auth/Stars.png', isNotEmpty); });",
      '// ai-apps:visual:end assets/auth/Stars.png',''].join('\n'));
    assert.equal(planAssetRemoval(root,asset).changes.length,2,
      'Explicitly owned tests are included in the same edit');

    fs.writeFileSync(path.join(root,'README.md'),
      'Pantalla usa Stars.png para dibujar el fondo.\n');
    assert.throws(()=>planAssetRemoval(root,asset),/README.md/,
      'Stale documentation blocks deletion instead of remaining incorrect');
    fs.unlinkSync(path.join(root,'README.md'));
    fs.unlinkSync(fixtureTest);
    fs.writeFileSync(dart,source);

    fs.writeFileSync(path.join(root,'assets','auth','Pending.png'),'pending');
    const pending='assets/auth/Pending.png';
    assert.equal(planPendingAssetRemoval(root,pending).asset,pending);
    fs.writeFileSync(fixtureTest,
      "Image.asset('assets/auth/Pending.png');\n");
    assert.throws(()=>planPendingAssetRemoval(root,pending),/auth_test.dart/,
      'Pending images with test references are not safe to delete');
    fs.unlinkSync(fixtureTest);

    assert.equal(isValidImage(fs.readFileSync(image),'.png'),true);
    assert.equal(isValidImage(Buffer.from('not an image'),'.png'),false);
    assert.equal(isValidImage(Buffer.from('RIFFxxxxWEBP'),'.webp'),true);
    console.log('PASS: borrado integral, tests, propiedades, documentación, pendientes y rutas');
  } finally {
    fs.rmSync(root,{recursive:true,force:true});
  }
}
main();

