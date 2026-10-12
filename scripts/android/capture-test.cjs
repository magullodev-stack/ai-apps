const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { Sessions, key, writeJson } = require('./sessions.cjs');
const { Windows } = require('./windows.cjs');

async function main() {
  const root = path.resolve(__dirname, '../../.ai-apps/android-tests', crypto.randomUUID());
  const image = Buffer.from('89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de0000000c49444154789c635072490300015800cd75c1fe1a0000000049454e44ae426082', 'hex');
  const app = { appId: 'lab-vision', label: 'Vision', serial: 'emulator-5558', avdName: 'AI_APPS_Lab_Vision',
    projectPath: path.join(root, 'app'), packageName: 'dev.lab.vision', kind: 'flutter' };
  const windows = new Windows(root), calls = [];
  let focused = app.packageName, resumed = app.packageName, avd = app.avdName, boot = 'boot', changeDuringCapture = false;
  windows.run = async (file, args, options) => {
    calls.push(args);
    assert.equal(args[1], app.serial, 'Every ADB operation targets only the experiment');
    if (args.includes('pidof')) return '321';
    if (args.includes('window')) {
      assert.equal(args.at(-1), 'displays', 'Android 36 exposes focus in displays, not windows');
      return `Display: mDisplayId=2\n mCurrentFocus=Window{other u0 com.other.display/.Activity}\nDisplay: mDisplayId=0 (organized)\n mCurrentFocus=Window{abc u0 ${focused}/.MainActivity}`;
    }
    if (args.includes('activity')) return `Display #2 (activities):\n topResumedActivity=ActivityRecord{abc u0 com.other.display/.Activity}\nDisplay #0 (activities):\n topResumedActivity=ActivityRecord{abc u0 ${resumed}/.MainActivity t3}`;
    if (args.includes('getprop')) return avd;
    if (args.includes('cat')) return boot;
    if (args.includes('screencap')) {
      assert.equal(options.encoding, 'buffer', 'PNG bytes are never text-decoded');
      if (changeDuringCapture) boot = 'changed';
      return image;
    }
    throw new Error('Unexpected ADB operation');
  };
  const platform = { capture: session => windows.capture(session) };
  const service = new Sessions(root, platform);
  service.register(app);
  const lease = { pid: process.pid, token: 'worker' };
  writeJson(service.leaseFile(app), lease);
  const stateFile = path.join(service.directory(app), 'state.json');
  writeJson(stateFile, { status: 'running', token: lease.token });
  await assert.rejects(service.capture('muondia@emulator-5554'), /independently/);
  assert.equal(calls.length, 0, 'Primary capture is rejected before ADB');
  const captured = await service.capture(key(app));
  assert.equal(captured.appPid, '321');
  assert.equal(captured.epoch, 'worker:321');
  assert.ok(fs.readFileSync(captured.file).equals(image));
  assert.equal(captured.sha256, crypto.createHash('sha256').update(image).digest('hex'));
  const captures = path.dirname(captured.file);
  const count = () => fs.readdirSync(captures).length;
  for (const problem of ['focus', 'resume', 'avd', 'boot']) {
    focused = resumed = app.packageName; avd = app.avdName; boot = 'boot'; changeDuringCapture = false;
    if (problem === 'focus') focused = 'com.android.systemui';
    if (problem === 'resume') resumed = 'com.other.application';
    if (problem === 'avd') avd = 'AI_APPS_Dev';
    if (problem === 'boot') changeDuringCapture = true;
    const previous = count(), screenshots = calls.filter(args => args.includes('screencap')).length;
    await assert.rejects(service.capture(key(app)), /owner/);
    assert.equal(count(), previous, 'No unrelated or unverified pixels are persisted');
    if (problem !== 'boot') assert.equal(calls.filter(args => args.includes('screencap')).length, screenshots);
  }
  changeDuringCapture = false; focused = resumed = app.packageName; avd = app.avdName; boot = 'boot';
  platform.capture = async session => {
    const result = await windows.capture(session);
    writeJson(stateFile, { status: 'running', token: 'new-worker' });
    return result;
  };
  await assert.rejects(service.capture(key(app)), /same running/);
  assert.equal(count(), 1, 'Restarted owner cannot publish a stale screenshot');
  writeJson(stateFile, { status: 'stopped', token: lease.token });
  await assert.rejects(service.capture(key(app)), /same running/);
  console.log('PASS: binary screenshot, app/device/AVD/focus/resume/boot/worker ownership, rejected primary and failed captures without persisted pixels.');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
