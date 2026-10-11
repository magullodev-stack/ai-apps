const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { Windows } = require('./windows.cjs');

async function run() {
  const root = path.resolve(__dirname, '../..');
  const dir = path.join(root, '.ai-apps/runner-test');
  fs.mkdirSync(dir, { recursive: true });
  const { dart } = await new Windows(root).flutterTools();
  const capture = path.join(dir, 'args.json');
  const fake = path.join(dir, 'fake-flutter.cjs');
  fs.writeFileSync(fake, `require('node:fs').writeFileSync(${JSON.stringify(capture)},JSON.stringify(process.argv.slice(2)));`);
  const batch = path.join(dir, 'fake-flutter.bat');
  fs.writeFileSync(batch, `@echo off\r\n"${process.execPath}" "${fake}" %*\r\n`);
  const defines = path.join(dir, 'defines.json'); fs.writeFileSync(defines, '{}');
  const base = [path.join(root, 'scripts/flutter-dev-runner.dart'), '--flutter', batch,
    '--device', 'test-device', '--working-directory', dir, '--defines-file', defines, '--watch', dir];
  const options = { cwd: dir, windowsHide: true, encoding: 'utf8', env: { ...process.env, ELECTRON_RUN_AS_NODE: '1' }, timeout: 30000 };
  execFileSync(dart, base, options);
  const original = JSON.parse(fs.readFileSync(capture));
  assert.deepEqual(original, ['run', '--machine', '-d', 'test-device', `--dart-define-from-file=${defines}`],
    'Default invocation stays byte-for-byte compatible with QuizAI');
  execFileSync(dart, [...base, '--no-dds'], options);
  const managed = JSON.parse(fs.readFileSync(capture));
  assert.deepEqual(managed, ['run', '--machine', '--no-dds', '-d', 'test-device', `--dart-define-from-file=${defines}`]);
  const machine = path.join(dir, 'fake-machine.cjs');
  const machineBatch = path.join(dir, 'fake-machine.bat');
  fs.mkdirSync(path.join(dir, 'build'), { recursive: true });
  const messages = path.join(dir, 'build/messages.json');
  const descendants = path.join(dir, 'build/descendants.json');
  const sleeper = path.join(dir, 'sleeper.cjs');
  fs.writeFileSync(sleeper, 'setInterval(()=>{},1000);');
  fs.writeFileSync(machineBatch, `@echo off\r\n"${process.execPath}" "${machine}" %*\r\n`);
  fs.writeFileSync(machine, `
const fs=require('node:fs'), path=require('node:path');
const root=${JSON.stringify(dir)}, messages=${JSON.stringify(messages)};
fs.mkdirSync(path.join(root,'android/app'),{recursive:true});
fs.mkdirSync(path.join(root,'android/.gradle/cache'),{recursive:true});
console.log(JSON.stringify([{event:'app.start',params:{appId:'fixture',deviceId:'test-device'}},{event:'app.started'}]));
if(process.env.FAKE_NATIVE==='1') {
 const child=require('node:child_process').spawn(process.execPath,[${JSON.stringify(sleeper)}],{windowsHide:true,stdio:'ignore',env:process.env});
 fs.writeFileSync(${JSON.stringify(descendants)},JSON.stringify({parent:process.pid,child:child.pid}));
 setTimeout(()=>fs.writeFileSync(path.join(root,'android/app/build.gradle'),'// native change '+Date.now()),300);
 setInterval(()=>{},1000);
} else {
 setTimeout(()=>{
  fs.writeFileSync(path.join(root,'android/local.properties'),'sdk.dir=fixture');
  fs.writeFileSync(path.join(root,'android/.gradle/cache/generated.properties'),'fixture=true');
  fs.writeFileSync(path.join(root,'android/.gradle/cache/generated.json'),'{}');
  fs.writeFileSync(path.join(root,'main.dart'),'void main() {} // '+Date.now());
 },200);
 const received=[];
 require('node:readline').createInterface({input:process.stdin}).on('line',line=>{
  const request=JSON.parse(line)[0]; received.push(request); fs.writeFileSync(messages,JSON.stringify(received));
  console.log(JSON.stringify([{id:request.id,result:{code:0}}]));
 });
 setTimeout(()=>process.exit(0),2200);
}
`);
  const watchArgs = base.map(item => item === batch ? machineBatch : item);
  const output = execFileSync(dart, watchArgs, options);
  const reloads = JSON.parse(fs.readFileSync(messages));
  assert.equal(reloads.length, 1, 'Generated Android SDK/Gradle files do not cancel source watching');
  assert.equal(reloads[0].params.fullRestart, false);
  assert.match(output, /Hot reload automatico completado/);
  assert.doesNotMatch(output, /Cambio nativo/);
  assert.throws(() => execFileSync(dart, watchArgs, { ...options, env: { ...options.env, FAKE_NATIVE: '1' } }),
    error => error.status === 86, 'Native relaunch exits through the worker restart protocol');
  const owned = JSON.parse(fs.readFileSync(descendants));
  for (const pid of [owned.parent, owned.child]) {
    assert.throws(() => process.kill(pid, 0), 'Relaunch removes only the owned Flutter wrapper and descendants');
  }
  console.log('PASS: actual Dart runner, legacy default arguments unchanged, managed no-dds option per-device machine mode, generated Android files, automatic reload and native tree cleanup.');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
