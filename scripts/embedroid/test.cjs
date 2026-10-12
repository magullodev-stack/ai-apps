const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { execFileSync } = require('node:child_process');
const { EventEmitter } = require('node:events');
const { generateScid } = require('./scid.cjs');

const extensionPath = path.resolve(__dirname, '../../.ai-apps/embedroid/extension');
const bundle = fs.readFileSync(path.join(extensionPath, 'dist/extension.js'), 'utf8');
const upstream = fs.readFileSync(path.join(__dirname, 'upstream/dist/extension.js'), 'utf8');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

// Expose the actual bundled class only inside this test VM. The shipped
// extension's exports and command API remain unchanged.
function loadStream(source, entropy, spawn) {
  const sandbox = {
    module: { exports: {} }, Buffer, console, process,
    setTimeout, clearTimeout, setInterval, clearInterval, URLSearchParams,
    require(name) {
      if (name === 'vscode') return {
        TreeItem: class {},
        workspace: { getConfiguration: () => ({ get: (_, fallback) => fallback }) }
      };
      if (name === 'crypto') return { ...crypto, randomBytes: entropy };
      if (name === '../scid.cjs') return { generateScid: () => generateScid(entropy) };
      if (name === 'child_process' && spawn) return { ...require(name), spawn };
      return require(name);
    }
  };
  vm.runInNewContext(`${source}\n;module.exports.__stream = Se;`, sandbox);
  return sandbox.module.exports.__stream;
}

function fixedEntropy(hex) {
  return size => {
    assert.equal(size, 4);
    return Buffer.from(hex, 'hex');
  };
}

async function unitTests() {
  for (const [input, expected] of [
    ['00000000', '00000000'], ['00000001', '00000001'],
    ['7fffffff', '7fffffff'], ['80000000', '00000000'],
    ['cf1b8d37', '4f1b8d37'], ['ffffffff', '7fffffff']
  ]) assert.equal(generateScid(fixedEntropy(input)), expected);
  for (let i = 0; i < 100000; i++) {
    const id = generateScid();
    assert.match(id, /^[0-7][0-9a-f]{7}$/);
    assert.ok(parseInt(id, 16) <= 0x7fffffff);
  }
  assert.equal(bundle.split('require("../scid.cjs").generateScid()').length - 1, 2);
  assert.ok(!bundle.includes('Xe.randomBytes(4).toString("hex")'));
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(extensionPath, 'package.json'))).publisher, 'magullodev');

  const Original = loadStream(upstream, fixedEntropy('ffffffff'));
  assert.equal(new Original('test', {}, extensionPath, {}).scid, 'ffffffff', 'Original reproduces invalid ID');
  for (const input of ['80000000', 'ffffffff']) {
    let serverArgs;
    const spawn = (_, args) => {
      serverArgs = args;
      return Object.assign(new EventEmitter(), { stdout: new EventEmitter(), stderr: new EventEmitter() });
    };
    const Stream = loadStream(bundle, fixedEntropy(input), spawn);
    const stream = new Stream('test', {}, extensionPath, { info() {}, warn() {} });
    const expected = generateScid(fixedEntropy(input));
    assert.equal(stream.scid, expected, 'Constructor uses fixed generator');
    let forwarded;
    stream.adb = async args => { forwarded = args; return { stdout: '12345' }; };
    stream.connectVideo = async () => stream.onStarted();
    await stream.launchAndConnect();
    assert.equal(forwarded[2], `localabstract:scrcpy_${expected}`);
    assert.ok(serverArgs.includes(`scid=${expected}`), 'Server and forward share ID');
  }
  console.log('PASS: boundaries, 100000 random IDs, original regression and both real transport call sites.');
}

async function deviceTests(serial) {
  const sdk = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT || path.join(process.env.LOCALAPPDATA, 'Android/Sdk');
  const adb = path.join(sdk, 'platform-tools/adb.exe');
  const runAdb = args => execFileSync(adb, ['-s', serial, ...args], { encoding: 'utf8', windowsHide: true }).trim();
  const before = {
    boot: runAdb(['shell', 'cat', '/proc/sys/kernel/random/boot_id']),
    muondia: runAdb(['shell', 'pidof', 'com.aiapps.muondia'])
  };
  assert.equal(runAdb(['get-state']), 'device');
  // Demonstrate rejection by the exact server we ship, without opening any
  // socket or touching an existing streaming process.
  const remoteJar = '/data/local/tmp/androidplug-scrcpy-server.jar';
  runAdb(['push', path.join(extensionPath, 'media/vendor/scrcpy-server-v3.2.jar'), remoteJar]);
  let rejection;
  try {
    runAdb(['shell', `CLASSPATH=${remoteJar}`, 'app_process', '/',
      'com.genymobile.scrcpy.Server', '3.2', 'scid=ffffffff', 'power_on=false']);
    assert.fail('Server must reject the original 32-bit ID');
  } catch (error) {
    rejection = String(error.stderr || error.stdout || error.message);
    assert.match(rejection, /NumberFormatException/);
    assert.equal(error.status, 1);
  }
  console.log('PASS: bundled scrcpy rejects ffffffff with NumberFormatException and code 1.');
  const cycles = [];
  for (const entropy of ['80000000', 'ffffffff', 'cf1b8d37']) {
    const messages = [];
    const errors = [];
    let frames = 0;
    let firstFrames = 0;
    let init;
    const Stream = loadStream(bundle, fixedEntropy(entropy));
    const stream = new Stream(serial, { resolve: async () => ({ adb }) }, extensionPath, {
      info: message => messages.push(message), warn: message => messages.push(message)
    });
    try {
      await stream.start({
        onInit: value => { init = value; },
        onVideo: () => frames++,
        onError: error => errors.push(error.message),
        onClose: () => errors.push('Unexpected stream close')
      });
      await delay(1000);
      firstFrames = frames;
      await delay(9000);
      assert.equal(errors.length, 0, errors.join('; '));
      assert.equal(init.codec, 'h264');
      assert.ok(init.width > 0 && init.height > 0);
      assert.ok(firstFrames > 0 && frames > firstFrames, 'Video continues throughout the cycle');
      assert.ok(messages.some(message => message.includes('established on attempt 1')));
      assert.ok(!messages.some(message => /launch attempt .* failed/.test(message)));
      cycles.push({ entropy, scid: stream.scid, frames, init, sustainedSeconds: 10, attempts: 1 });
      console.log(`PASS: entropy ${entropy} -> scid ${stream.scid}, ${frames} H.264 frames, 10s, first attempt.`);
    } finally { await stream.stop(); }
  }
  const after = {
    boot: runAdb(['shell', 'cat', '/proc/sys/kernel/random/boot_id']),
    muondia: runAdb(['shell', 'pidof', 'com.aiapps.muondia'])
  };
  assert.deepEqual(after, before, 'Android and Muondia remain running');
  const report = { passed: true, before, after, cycles };
  fs.writeFileSync(path.join(extensionPath, '../device-test-result.json'), JSON.stringify(report, null, 2));
  console.log('PASS: Android boot ID and Muondia PID unchanged.');
}

(async () => {
  await unitTests();
  const deviceIndex = process.argv.indexOf('--device');
  if (deviceIndex !== -1) await deviceTests(process.argv[deviceIndex + 1]);
})().catch(error => { console.error(error); process.exitCode = 1; });
