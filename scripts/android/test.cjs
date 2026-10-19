'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {Sessions, key} = require('./sessions.cjs');
async function run() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ai-apps-android-'));
  const appDir = path.join(root, 'sample');
  fs.mkdirSync(appDir);
  fs.writeFileSync(path.join(appDir, 'pubspec.yaml'), 'name: sample\n');
  let running = false;
  const platform = {
    devices: async () => ['emulator-5554', 'emulator-5556'],
    appPid: async s => s.appId === 'muondia' || running ? '100' : ''
  };
  // Una sesion heredada que apunta a un proyecto borrado no debe
  // bloquear el arranque de Muondia ni reescribir automaticamente el JSON.
  const registryFile = path.join(root, '.ai-apps/android/sessions.json');
  fs.mkdirSync(path.dirname(registryFile), {recursive: true});
  const legacyRegistry = JSON.stringify({version: 1, sessions: [
    {appId: 'old-lab', label: 'Old lab', kind: 'flutter',
      serial: 'emulator-5558', avdName: 'Old_AVD',
      projectPath: path.join(root, 'deleted-lab'),
      packageName: 'com.example.old'},
  ]});
  fs.writeFileSync(registryFile, legacyRegistry);
  const sessions = new Sessions(root, platform);
  assert.deepEqual(sessions.definitions().map(s => s.appId), ['muondia'],
    'A stale registration must never block the default Muondia app');
  assert.equal(fs.readFileSync(registryFile, 'utf8'), legacyRegistry,
    'Reading the registry must not delete user records');
  assert.equal((await sessions.list())[0].appId, 'muondia');
  assert.equal(sessions.definitions()[0].appId, 'muondia');
  assert.equal(sessions.definitions()[0].kind, 'flutter');
  const other = {appId:'sample',label:'Sample',serial:'emulator-5556',
    avdName:'Sample_AVD',packageName:'com.example.sample',
    projectPath: appDir,kind:'flutter'};
  sessions.register(other);
  sessions.register(other);
  assert.equal(sessions.definitions().length, 2);
  assert.throws(() => sessions.register({...other,serial:'emulator-5554'}));
  assert.throws(() => sessions.register({...other,appId:'muondia'}));
  assert.throws(() => sessions.register({...other,appId:'duplicate'}));
  let list = await sessions.list();
  assert.equal(list[0].active, true);
  assert.equal(list[1].active, false);
  assert.equal(list[1].status, 'stopped');
  running = true;
  list = await sessions.list();
  assert.equal(list[1].active, true);
  await assert.rejects(sessions.unregister(key(other)), /Stop application/);
  running = false;
  await sessions.unregister(key(other));
  assert.equal(sessions.definitions().length, 1);
  await assert.rejects(sessions.unregister('muondia@emulator-5554'), /reserved/);
  fs.rmSync(root, {recursive:true,force:true});
  console.log('PASS: registro Android sin procesos Flutter propios ni tarea de Windows');
}
run().catch(error => {console.error(error);process.exitCode=1});
