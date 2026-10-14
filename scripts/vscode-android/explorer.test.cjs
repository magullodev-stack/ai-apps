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
   TreeItemCollapsibleState:{None:0,Collapsed:1}};
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
  assert.deepEqual(children.map(x=>x.label),['Auth','Primera experiencia','Home']);
  assert.deepEqual(children.map(x=>x.kind),['experience','group','experience']);
  const groupChildren=explorer.provider.getChildren(children[1]);
  assert.deepEqual(groupChildren.map(x=>x.label),
    ['Loading del robot','Test de bienvenida']);
  const loading=groupChildren[0];
  assert.deepEqual(explorer.provider.getChildren(loading).map(x=>x.state.id),
    ['inicio','progreso','final']);
  assert.equal(explorer.provider.getTreeItem(children[0]).command.arguments[1],'auth');
  assert.equal(explorer.provider.getTreeItem(children[2]).command.arguments[1],'home');
  await explorer.open(session.id,'loading','progreso');
  assert.deepEqual(calls[0],['adb.exe',['-s','emulator-5554','shell','am','start',
    '-n','com.aiapps.muondia/.MainActivity','-a','com.aiapps.muondia.DEV_OPEN_EXPERIENCE',
    '-f','0x20000000','--es','experience','loading','--es','state','progreso']]);
  await assert.rejects(explorer.open(session.id,'invalid','inicio'),/no registrada/);
  await assert.rejects(explorer.open(session.id,'loading','invalid'),/no registrada/);
  assert.equal(calls.length,1);
  ready=false;await assert.rejects(explorer.open(session.id,'auth','inicio'),/desconectado/);
  ready=true;pid='';await assert.rejects(explorer.open(session.id,'home','inicio'),/no está ejecutándose/);
  assert.equal(calls.length,1);
  catalog.experiences[0].id='auth; reboot';
  fs.writeFileSync(path.join(directory,'experiences.json'),JSON.stringify(catalog));
  assert.throws(()=>readCatalog(session),/Experiencia inválida/);
  assert.equal(explorer.refresh(await service.list()),true,
    'changing the catalog causes exactly one tree refresh');
  assert.equal(explorer.refresh(await service.list()),false,
    'subsequent polls do not redraw after catalog changes');
  console.log('PASS: catálogo, árbol, comando ADB y validación');
 }finally{fs.rmSync(temp,{recursive:true,force:true})}
}
main().catch(e=>{console.error(e);process.exitCode=1});

