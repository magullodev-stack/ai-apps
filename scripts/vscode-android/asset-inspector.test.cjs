'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { listVisualAssets, createVisualAssetInspector } = require('./asset-inspector.cjs');

async function main() {
  const base = fs.mkdtempSync(path.join(os.tmpdir(), 'ai-apps-layers-'));
  try {
    const dir = path.join(base, 'assets', 'auth');
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(base, 'pubspec.yaml'), 'name: test\n');
    fs.writeFileSync(path.join(dir, 'Layer.png'), 'dummy');
    fs.writeFileSync(path.join(dir, 'Overlay.png'), 'dummy');
    fs.writeFileSync(path.join(dir, 'readme.txt'), 'not an image');
    fs.mkdirSync(path.join(base, 'lib', 'app', 'development'), {recursive: true});
    fs.writeFileSync(path.join(base, 'lib', 'app', 'auth.dart'), [
      "Image.asset('assets/auth/Layer.png');",
      "Image.asset('assets/auth/Overlay.png');",
    ].join('\n') + '\n');
    fs.writeFileSync(path.join(base, 'lib', 'app', 'development', 'experiences.json'),
      JSON.stringify({version: 1, activity:'com.aiapps.muondia/.MainActivity',
        experiences:[{id:'auth', label:'Auth',group:'Acceso',
          states:[{id:'inicio',label:'Inicio'}]}]}));
    const session = { id: 'muondia@emulator-5554', label:'Muondia',
      kind:'development-task', packageName:'com.aiapps.muondia',
      serial:'emulator-5554', projectPath:base, deviceReady:true };
    const calls = [];
    const svc = { async list() { return [session]; },
      platform: {adb:'adb.exe',async appPid(){return '123';},
        async run(...args){calls.push(args);} } };
    const vscode = { TreeItem: class { constructor(label, state) {
      this.label=label;this.collapsibleState=state;
    }},ThemeIcon:class{constructor(name){this.id=name}},
    Uri:{file:fsPath=>({fsPath})},
    TreeItemCollapsibleState:{Collapsed:1,None:0}};
    const inspector = createVisualAssetInspector(vscode,svc,()=>{});
    assert.deepEqual(listVisualAssets(base),
      ['assets/auth/Layer.png','assets/auth/Overlay.png']);
    assert.equal(inspector.refresh([session]),true);
    assert.equal(inspector.refresh([session]),false);
    const images = inspector.forExperience(session,
      {id:'auth',assetDirectories:['assets/auth']});
    assert.equal(images.length,2);
    assert.equal(inspector.forExperience(session,
      {id:'home',assetDirectories:['assets/home']}).length,0);
    assert.equal(inspector.forExperience(session,
      {id:'test',assetDirectories:[]}).length,0);
    assert.deepEqual(images.map(item=>item.kind),
      ['visualAsset','visualAsset'], 'Images belong directly to their UI screen');
    // Un mapa de referencias literales admite selección dinámica en Flutter.
    const pivotsDir = path.join(base, 'assets', 'Pivotes');
    fs.mkdirSync(pivotsDir, {recursive:true});
    fs.writeFileSync(path.join(pivotsDir, 'P01 - Arquitectura.png'), 'dummy');
    fs.writeFileSync(path.join(base, 'lib', 'app', 'pivot_images.dart'),
      "const paths = {'P01': 'assets/Pivotes/P01 - Arquitectura.png'};\n");
    const pivotEntries = inspector.forExperience(session,
      {id:'test',assetDirectories:['assets/Pivotes']});
    assert.equal(pivotEntries.length, 1);
    assert.equal(inspector.getTreeItem(pivotEntries[0]).contextValue,
      'visualAssetVisible',
      'La imagen dinamica usada por la pregunta no debe figurar Pendiente');
    assert.equal(inspector.getTreeItem(pivotEntries[0]).description, '',
      'La imagen esta vinculada, sin afirmar que siempre esta en pantalla');
    const stars = images.find(i=>i.asset.endsWith('Layer.png'));
    assert.equal(inspector.getTreeItem(stars).contextValue,'visualAssetVisible');
    await inspector.toggle(session.id,stars.asset);
    assert.equal(inspector.getTreeItem(stars).description,'Oculta');
    assert.equal(inspector.getTreeItem(stars).contextValue,'visualAssetHidden');
    assert.equal(inspector.getTreeItem(stars).command.command,'vscode.open');
    assert.deepEqual(calls.at(-1),['adb.exe',[
      '-s','emulator-5554','shell','am','start',
      '-n','com.aiapps.muondia/.MainActivity',
      '-a','com.aiapps.muondia.DEV_ASSET_VISIBILITY',
      '-f','0x20000000','--es','asset','assets/auth/Layer.png',
      '--ez','visible','false']]);
    await inspector.toggle(session.id,stars.asset);
    assert.equal(inspector.getTreeItem(stars).contextValue,'visualAssetVisible');
    assert.equal(calls.at(-1)[1].at(-1),'true');
    fs.writeFileSync(path.join(dir, 'Luna.png'), 'dummy');
    assert.equal(inspector.refresh([session]),true,
      'New files invalidate the tree snapshot');
    const pending = inspector.forExperience(session,
      {id:'auth',assetDirectories:['assets/auth']})
      .find(item=>item.asset.endsWith('Luna.png'));
    assert.equal(inspector.getTreeItem(pending).contextValue,'visualAssetPending');
    assert.equal(inspector.getTreeItem(pending).description,'⏳ Pendiente');
    await assert.rejects(inspector.toggle(session.id,pending.asset),/pendiente/);
    fs.appendFileSync(path.join(base, 'lib', 'app', 'auth.dart'),
      "Image.asset('assets/auth/Luna.png');\n");
    assert.equal(inspector.refresh([session]),true,
      'Changes in Dart also invalidate the UI view');
    const placed = inspector.forExperience(session,
      {id:'auth',assetDirectories:['assets/auth']})
      .find(item=>item.asset.endsWith('Luna.png'));
    assert.equal(inspector.getTreeItem(placed).contextValue,'visualAssetVisible',
      'Pending becomes visible as soon as Dart references the image');
    await assert.rejects(
      inspector.toggle(session.id,'../../secret.png'),/no disponible/);
    fs.unlinkSync(path.join(dir,'Layer.png'));
    assert.equal(inspector.forExperience(session,
      {id:'auth',assetDirectories:['assets/auth']}).length,2);
    await assert.rejects(inspector.toggle(session.id,stars.asset),/no disponible/);
    console.log('PASS: descubrimiento de PNG, visibilidad reversible y ADB validado');
  } finally {
    fs.rmSync(base,{recursive:true,force:true});
  }
}
main().catch(err=>{console.error(err);process.exitCode=1});

