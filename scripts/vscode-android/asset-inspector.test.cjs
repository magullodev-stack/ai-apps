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
    fs.writeFileSync(path.join(dir, 'Estrellas.png'), 'dummy');
    fs.writeFileSync(path.join(dir, 'Esferas.png'), 'dummy');
    fs.writeFileSync(path.join(dir, 'readme.txt'), 'not an image');
    fs.mkdirSync(path.join(base, 'lib', 'app', 'development'), {recursive: true});
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
      ['assets/auth/Esferas.png','assets/auth/Estrellas.png']);
    const node = inspector.root(session);
    const [folder] = inspector.getChildren(node);
    assert.equal(folder.folderPath,'assets/auth');
    const images = inspector.getChildren(folder);
    assert.equal(images.length,2);
    const stars = images.find(i=>i.asset.endsWith('Estrellas.png'));
    assert.equal(inspector.getTreeItem(stars).contextValue,'visualAssetVisible');
    await inspector.toggle(session.id,stars.asset);
    assert.equal(inspector.getTreeItem(stars).description,'Oculta');
    assert.equal(inspector.getTreeItem(stars).contextValue,'visualAssetHidden');
    assert.equal(inspector.getTreeItem(stars).command.command,'vscode.open');
    assert.deepEqual(calls.at(-1),['adb.exe',[
      '-s','emulator-5554','shell','am','start',
      '-n','com.aiapps.muondia/.MainActivity',
      '-a','com.aiapps.muondia.DEV_ASSET_VISIBILITY',
      '-f','0x20000000','--es','asset','assets/auth/Estrellas.png',
      '--ez','visible','false']]);
    await inspector.toggle(session.id,stars.asset);
    assert.equal(inspector.getTreeItem(stars).contextValue,'visualAssetVisible');
    assert.equal(calls.at(-1)[1].at(-1),'true');
    await assert.rejects(
      inspector.toggle(session.id,'../../secret.png'),/no disponible/);
    fs.unlinkSync(path.join(dir,'Estrellas.png'));
    assert.equal(inspector.getChildren(folder).length,1);
    await assert.rejects(inspector.toggle(session.id,stars.asset),/no disponible/);
    console.log('PASS: descubrimiento de PNG, visibilidad reversible y ADB validado');
  } finally {
    fs.rmSync(base,{recursive:true,force:true});
  }
}
main().catch(err=>{console.error(err);process.exitCode=1});

