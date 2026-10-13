const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { Sessions, key, writeJson } = require('./sessions.cjs');
const { runtimeEnv } = require('./windows.cjs');

async function run() {
  const root = path.resolve(__dirname, '../../.ai-apps/android-tests', crypto.randomUUID());
  fs.mkdirSync(path.join(root, 'app'), { recursive: true });
  fs.writeFileSync(path.join(root, 'app/pubspec.yaml'), 'name: android_test\n');
  const calls = [];
  let busy = false, taskActive = true;
  const platform = {
    devices: async () => ['emulator-5554', 'emulator-5556'],
    appPid: async session => session.appId === 'muondia' ? '100' : '200',
    taskRunning: async () => taskActive, startTask: async () => calls.push('start-task'),
    stopTask: async () => calls.push('stop-task'), hasFlutter: async () => busy,
    spawnWorker(id, token, dir) { calls.push(['worker', id, token]); return process.pid; }
  };
  const service = new Sessions(root, platform);
  assert.equal(service.definitions()[0].serial, 'emulator-5554');
  assert.equal(fs.existsSync(service.file), false, 'Reading default does not mutate registration');
  const app = { appId: 'sample-counter', label: 'Sample counter', serial: 'emulator-5556',
    avdName: 'AI_APPS_Sample', projectPath: path.join(root, 'app'), packageName: 'com.example.counter', kind: 'flutter' };
  service.register(app);
  service.register(app); // Idempotent exact registration.
  assert.equal(new Sessions(root, platform).definitions().length, 2, 'Registration survives editor/CLI restart');
  for (const change of [{ serial: 'emulator-5554' }, { appId: 'muondia' }, { avdName: 'AI_APPS_Dev' },
    { appId: 'other' }, { serial: 'emulator-5557' }, { avdName: 'ai_apps_dev' },
    { appId: 'other', serial: 'emulator-5558', avdName: 'ai_apps_sample' }, { secret: 'private' }]) {
    assert.throws(() => service.register({ ...app, ...change }));
  }
  busy = true;
  await assert.rejects(service.start(key(app)), /Another Flutter/);
  assert.equal(calls.length, 0, 'Cannot launch a second Flutter on an owned device');
  busy = false;
  await Promise.all([service.start(key(app)), service.start(key(app))]);
  assert.equal(calls.filter(call => Array.isArray(call)).length, 1, 'Concurrent editor/CLI starts share one lease');
  await assert.rejects(service.unregister(key(app)), /Stop\/recover/);
  await assert.rejects(service.unregister('muondia@emulator-5554'), /reserved/);
  const list = await service.list();
  assert.equal(list[0].active, true);
  assert.equal(list[1].active, true);
  const lease = JSON.parse(fs.readFileSync(service.leaseFile(app)));
  const dir = service.directory(app);
  const stop = service.stop(key(app));
  assert.ok(fs.existsSync(path.join(dir, `${lease.token}.stop.json`)), 'Stop is an ownership-token request, not a PID kill');
  fs.unlinkSync(service.leaseFile(app));
  await stop;
  writeJson(service.leaseFile(app), lease);
  const failedStop = service.stop(key(app));
  writeJson(path.join(dir, 'state.json'), { status: 'failed', token: lease.token });
  fs.unlinkSync(service.leaseFile(app));
  await assert.rejects(failedStop, /stop failed/, 'A failed process/app stop is never reported as success');
  assert.equal(calls.includes('stop-task'), false, 'Stopping another app does not touch AI-APPS Development');
  await service.start('muondia@emulator-5554');
  assert.equal(calls.includes('start-task'), false, 'Starting active legacy task is a no-op');
  taskActive = false;
  await service.start('muondia@emulator-5554');
  await service.stop('muondia@emulator-5554');
  assert.deepEqual(calls.filter(call => typeof call === 'string'), ['start-task', 'stop-task']);
  const external = { appId: 'external', label: 'External', serial: 'emulator-5558', packageName: 'com.example.external', kind: 'external' };
  service.register(external);
  await assert.rejects(service.start(key(external)), /controlled by their owner/);
  await assert.rejects(service.stop(key(external)), /through its owner/);
  writeJson(service.leaseFile(app), { token: 'stale', pid: 2147483647 });
  await assert.rejects(service.stop(key(app)), /unverified process/);
  busy = true;
  await assert.rejects(service.start(key(app)), /existing Flutter/);
  for (let i = 0; i < 120; i++) service.register({ appId: `external-${i}`, label: `App ${i}`,
    serial: `test-${i}`, packageName: 'com.example.external', kind: 'external' });
  assert.equal(service.definitions().length, 123, 'No fixed session/tab count');
  busy = false;
  platform.devices = async () => ['emulator-5554', 'emulator-5556', 'emulator-5558'];
  await assert.rejects(service.unregister(key(external)), /still running/);
  platform.appPid = async session => session.appId === 'muondia' ? '100' : '';
  await service.unregister(key(external));
  assert.equal(service.definitions().length, 122);
  assert.equal(service.definitions()[0].serial, 'emulator-5554');
  fs.unlinkSync(service.leaseFile(app)); // Remove the deliberately stale offline fixture lease.
  let releaseRemoval;
  platform.hasFlutter = async () => new Promise(resolve => { releaseRemoval = resolve; });
  const removal = service.unregister(key(app));
  await assert.rejects(service.start(key(app)), /unregistration is in progress/);
  releaseRemoval(false);
  await removal;
  assert.equal(service.definitions().length, 121);
  process.env.AI_APPS_AI_API_KEY = 'private'; process.env.OPENAI_API_KEY = 'private';
  process.env.GIT_DIR = 'private';
  const env = runtimeEnv();
  for (const name of ['AI_APPS_AI_API_KEY', 'OPENAI_API_KEY', 'GIT_DIR']) assert.equal(env[name], undefined);
  console.log('PASS: persistent registry, reserved Muondia, exclusive devices/AVDs, concurrent starts, independent stop, stale lease protection, 123 sessions and sanitized environment.');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
