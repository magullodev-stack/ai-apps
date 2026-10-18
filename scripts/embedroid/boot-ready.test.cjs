'use strict';
const assert = require('node:assert/strict');
const { probeAndroidBoot, waitForBoot } = require('./boot-ready.cjs');

async function run() {
  const calls = [];
  let ready = await probeAndroidBoot('adb.exe', 'emulator-5554',
    async (cmd, args, options) => {
      calls.push({ cmd, args, options });
      return { stdout: '1\r\n' };
    });
  assert.equal(ready, true);
  assert.deepEqual(calls[0].args,
    ['-s', 'emulator-5554', 'shell', 'getprop', 'sys.boot_completed']);
  assert.equal(calls[0].options.timeout, 5000);
  assert.equal(await probeAndroidBoot('adb.exe', 'bad;serial',
    async () => { throw new Error('must not execute'); }), false);
  assert.equal(await probeAndroidBoot('adb.exe', 'emulator-5554',
    async () => ({ stdout: '0\r\n' })), false);
  assert.equal(await probeAndroidBoot('adb.exe', 'emulator-5554',
    async () => { throw new Error('adb offline'); }), false);

  let checks = 0;
  let waits = 0;
  const started = await waitForBoot({
    probe: async () => ++checks === 3,
    pause: async () => { waits++; },
    timeoutMs: 1000
  });
  assert.equal(started, true);
  assert.equal(checks, 3);
  assert.equal(waits, 2);

  let closed = false;
  const cancelled = await waitForBoot({
    probe: async () => false,
    isClosed: () => closed,
    pause: async () => { closed = true; },
    timeoutMs: 1000
  });
  assert.equal(cancelled, false, 'Closing the viewer must cancel boot wait');

  await assert.rejects(waitForBoot({
    probe: async () => false,
    pause: async () => {},
    timeoutMs: 0
  }), /timed out/, 'Boot failures must be bounded');

  console.log('PASS: Android boot gate waits, cancels and times out safely.');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
