'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {readCatalog,createExperienceExplorer}=require('./explorer.cjs');
async function main(){
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'ai-apps-explorer-'));
 try{
  const directory=path.join(temp,'lib/app/development');fs.mkdirSync(directory,{recursive:true});
  const source=path.resolve(__dirname,'../../apps/muondia/lib/app/development/experiences.json');
  const catalog=JSON.parse(fs.readFileSync(source,'utf8'));
  fs.copyFileSync(source,path.join(directory,'experiences.json'));
  let ready=true,pid='42';const calls=[];
  const session={id:'muondia@emulator-5554',label:'Muondia',serial:'emulator-5554',projectPath:temp,packageName:'com.aiapps.muondia',kind:'development-task'};
  const service={async list(){return [{...session,deviceReady:ready}]},
   platform:{adb:'adb.exe',async appPid(){return pid},async run(...args){calls.push(args)}}};
  const vscode={EventEmitter:class{constructor(){this.event=()=>{}}fire(){}},
   TreeItem:class{constructor(label,collapsibleState){this.label=label;this.collapsibleState=collapsibleState}},
   TreeItemCollapsibleState:{None:0,Collapsed:1},
   ThemeIcon:class{constructor(id,color){this.id=id;this.color=color}},
   ThemeColor:class{constructor(id){this.id=id}}};
  // Smoke test: construir el proveedor debe funcionar sin un EventEmitter
  // independiente. Un fallo aquí impide registrar todo AI-APPS Android.
  const explorer=createExperienceExplorer(vscode,service,()=>{});
  assert.equal(typeof explorer.provider.getChildren,'function',
    'The nested tree provider must initialize before VS Code registration');
  assert.equal(explorer.refresh(await service.list()),true);
  assert.equal(explorer.refresh(await service.list()),false,
    'unchanged sessions do not trigger tree regeneration');
  const [app]=explorer.provider.getChildren();assert.equal(app.label,'Muondia');
  const children=explorer.provider.getChildren(app);
  assert.deepEqual(children.map(x=>x.label),
    ['Recorrido real','Acceso','Primera experiencia','Aplicación']);
  assert.deepEqual(children.map(x=>x.kind),['real','group','group','group']);
  const realItem=explorer.provider.getTreeItem(children[0]);
  assert.equal(realItem.command.command,'aiAppsAndroid.realFlow');
  const groupItem=explorer.provider.getTreeItem(children[1]);
  assert.equal(groupItem.label,'ACCESO', 'Group anchors are uppercase');
  assert.equal(groupItem.iconPath.id,'folder', 'Group anchors use a distinct icon');
  assert.equal(explorer.provider.getChildren(children[1])[0].label,'Auth');
  const groupChildren=explorer.provider.getChildren(children[2]);
  assert.deepEqual(groupChildren.map(x=>x.label),
    ['Loading del robot','Test de bienvenida']);
  const loading=groupChildren[0];
  assert.deepEqual(explorer.provider.getChildren(loading).map(x=>x.state.id),
    ['inicio','progreso','final']);
  const auth=explorer.provider.getChildren(children[1])[0];
  const home=explorer.provider.getChildren(children[3])[0];
  assert.equal(explorer.provider.getTreeItem(auth).command.arguments[1],'auth');
  assert.equal(explorer.provider.getTreeItem(home).command.arguments[1],'home');
  const search=explorer.findTargets();
  assert.equal(search.length,7, 'One real flow + six preview states');
  assert.ok(search.some(x=>x.mode==='preview' && x.description.includes('Primera experiencia')));
  assert.ok(search.some(x=>x.mode==='real' && x.label==='Recorrido real'));
  await explorer.open(session.id,'loading','progreso');
  assert.equal(explorer.activeLocation().group,'Primera experiencia');
  assert.equal(explorer.provider.getTreeItem(children[2]).description,
    '● ÚLTIMA SELECCIÓN', 'Active group must be unmistakable');
  assert.deepEqual(calls[0],['adb.exe',['-s','emulator-5554','shell','am','start',
    '-n','com.aiapps.muondia/.MainActivity','-a','com.aiapps.muondia.DEV_OPEN_EXPERIENCE',
    '-f','0x20000000','--es','experience','loading','--es','state','progreso']]);
  await assert.rejects(explorer.open(session.id,'invalid','inicio'),/no registrada/);
  await assert.rejects(explorer.open(session.id,'loading','invalid'),/no registrada/);
  assert.equal(calls.length,1);
  await explorer.openReal(session.id);
  assert.deepEqual(calls[1],['adb.exe',['-s','emulator-5554','shell','am','start',
    '-n','com.aiapps.muondia/.MainActivity',
    '-a','com.aiapps.muondia.DEV_OPEN_REAL_FLOW','-f','0x20000000']]);
  assert.equal(explorer.activeLocation().mode,'real');
  assert.equal(explorer.provider.getTreeItem(children[0]).description,'● MODO REAL');
  calls.pop(); // El resto de la prueba mantiene una única llamada inicial.
  ready=false;await assert.rejects(explorer.open(session.id,'auth','inicio'),/desconectado/);
  ready=true;pid='';await assert.rejects(explorer.open(session.id,'home','inicio'),/no está ejecutándose/);
  assert.equal(calls.length,1);
  // El catálogo nunca puede asignar las mismas imágenes a dos pantallas.
  catalog.experiences[1].assetDirectories=['assets/auth'];
  fs.writeFileSync(path.join(directory,'experiences.json'),JSON.stringify(catalog));
  assert.throws(()=>readCatalog(session),/Carpetas visuales compartidas/);
  catalog.experiences[1].assetDirectories=['assets/onboarding/loading'];
  catalog.experiences[0].assetDirectories=['assets/../auth'];
  fs.writeFileSync(path.join(directory,'experiences.json'),JSON.stringify(catalog));
  assert.throws(()=>readCatalog(session),/Carpetas visuales inválidas/);
  catalog.experiences[0].assetDirectories=['assets/Autenticación nueva'];
  fs.writeFileSync(path.join(directory,'experiences.json'),JSON.stringify(catalog));
  assert.deepEqual(readCatalog(session).experiences[0].assetDirectories,
    ['assets/Autenticación nueva'], 'Renamed paths may contain Unicode and spaces');
  catalog.experiences[0].assetDirectories=['assets/auth'];
  catalog.experiences[0].id='auth; reboot';
  fs.writeFileSync(path.join(directory,'experiences.json'),JSON.stringify(catalog));
  assert.throws(()=>readCatalog(session),/Experiencia inválida/);
  assert.equal(explorer.refresh(await service.list()),true,
    'changing the catalog causes exactly one tree refresh');
  assert.equal(explorer.refresh(await service.list()),false,
    'subsequent polls do not redraw after catalog changes');
  catalog.experiences[0].id='auth';
  catalog.experiences.push(...Array.from({length:40},(_,i)=>({
    id:'new-'+i,label:'Pantalla '+i,group:'Grupo '+i,
    states:[{id:'inicio',label:'Inicio'}],assetDirectories:[],
  })));
  fs.writeFileSync(path.join(directory,'experiences.json'),JSON.stringify(catalog));
  explorer.refresh(await service.list());
  assert.equal(explorer.provider.getChildren(app).length,44,
    'Many categories are not flattened or lost');
  assert.equal(explorer.findTargets().length,47,
    'Quick search covers every screen even with many categories');
  console.log('PASS: catálogo, árbol, comando ADB y validación');
 }finally{fs.rmSync(temp,{recursive:true,force:true})}
}
main().catch(e=>{console.error(e);process.exitCode=1});

