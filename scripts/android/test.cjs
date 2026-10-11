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
    appPid: async session => session.appId === 'quizai' ? '100' : '200',
    taskRunning: async () => taskActive, startTask: async () => calls.push('start-task'),
    stopTask: async () => calls.push('stop-task'), hasFlutter: async () => busy,
    spawnWorker(id, token, dir) { calls.push(['worker', id, token]); return process.pid; }
  };
  const service = new Sessions(root, platform);
  assert.equal(service.definitions()[0].serial, 'emulator-5554');
  assert.equal(fs.existsSync(service.file), false, 'Reading default does not mutate registration');
  const app = { appId: 'lab-counter', label: 'Lab counter', serial: 'emulator-5556',
    avdName: 'AI_APPS_Lab', projectPath: path.join(root, 'app'), packageName: 'com.example.counter', kind: 'flutter' };
  service.register(app);
  service.register(app); // Idempotent exact registration.
  assert.equal(new Sessions(root, platform).definitions().length, 2, 'Registration survives editor/CLI restart');
  for (const change of [{ serial: 'emulator-5554' }, { appId: 'quizai' }, { avdName: 'AI_APPS_Dev' },
    { appId: 'other' }, { serial: 'emulator-5557' }, { avdName: 'ai_apps_dev' },
    { appId: 'other', serial: 'emulator-5558', avdName: 'ai_apps_lab' }, { secret: 'private' }]) {
    assert.throws(() => service.register({ ...app, ...change }));
  }
  busy = true;
  await assert.rejects(service.start(key(app)), /Another Flutter/);
  assert.equal(calls.length, 0, 'Cannot launch a second Flutter on an owned device');
  busy = false;
  await Promise.all([service.start(key(app)), service.start(key(app))]);
  assert.equal(calls.filter(call => Array.isArray(call)).length, 1, 'Concurrent editor/CLI starts share one lease');
  await assert.rejects(service.unregister(key(app)), /Stop\/recover/);
  await assert.rejects(service.unregister('quizai@emulator-5554'), /reserved/);
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
  await service.start('quizai@emulator-5554');
  assert.equal(calls.includes('start-task'), false, 'Starting active legacy task is a no-op');
  taskActive = false;
  await service.start('quizai@emulator-5554');
  await service.stop('quizai@emulator-5554');
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
  platform.appPid = async session => session.appId === 'quizai' ? '100' : '';
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
  // The disposal contract removes only experiment-owned lab previews,
  // including their private runner logs and emulator resource.
  const runName = 'creative_20261011T150000_trial';
  const run = path.join(root, 'agent-lab', 'runs', runName);
  const workspace = path.join(run, 'workspace');
  fs.mkdirSync(workspace, { recursive: true });
  writeJson(path.join(run, 'manifest.json'), { run_id: runName, kind: 'creative' });
  fs.writeFileSync(path.join(workspace, 'pubspec.yaml'), 'name: temporary_preview\n');
  const fingerprint = crypto.createHash('sha256').update(runName).digest('hex').slice(0, 12);
  const disposable = {
    appId: 'lab-' + fingerprint, label: 'Lab temporary', serial: 'emulator-5560',
    avdName: 'AI_APPS_Lab_' + fingerprint,
    projectPath: workspace, packageName: 'com.example.temporary', kind: 'flutter'
  };
  platform.hasFlutter = async () => false;
  platform.devices = async () => ['emulator-5554'];
  platform.retireAvd = async session => calls.push(['retire-avd', session.avdName]);
  service.register(disposable);
  await assert.rejects(service.discard('quizai@emulator-5554'), /Only owned/);
  const done = await service.discard(key(disposable));
  assert.equal(done.discarded, key(disposable));
  assert.equal(fs.existsSync(run), false, 'Discard removes the generated workspace and logs');
  assert.equal(fs.existsSync(service.directory(disposable)), false, 'Discard removes private Android records');
  assert.equal(service.definitions().length, 121, 'Discard unregisters only the disposable preview');
  assert.equal(service.definitions()[0].appId, 'quizai', 'QuizAI remains registered');
  assert.ok(calls.some(item => Array.isArray(item) && item[0] === 'retire-avd'));

  process.env.AI_APPS_AI_API_KEY = 'private'; process.env.OPENAI_API_KEY = 'private';
  process.env.CODEX_API_KEY = 'private'; process.env.GIT_DIR = 'private';
  const env = runtimeEnv();
  for (const name of ['AI_APPS_AI_API_KEY', 'OPENAI_API_KEY', 'CODEX_API_KEY', 'GIT_DIR']) assert.equal(env[name], undefined);
  console.log('PASS: persistent registry, reserved QuizAI, exclusive devices/AVDs, concurrent starts, independent stop, stale lease protection, 123 sessions and sanitized environment.');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
