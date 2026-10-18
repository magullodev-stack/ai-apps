'use strict';
const { execFile } = require('node:child_process');
const { promisify } = require('node:util');
const execute = promisify(execFile);

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

// Only read Android state. Never boot, stop, reset or modify the device.
async function probeAndroidBoot(adb, serial, run = execute) {
  if (!/^emulator-[0-9]+$/.test(serial) || !adb) return false;
  try {
    const { stdout } = await run(adb,
      ['-s', serial, 'shell', 'getprop', 'sys.boot_completed'],
      { windowsHide: true, timeout: 5000 });
    return stdout.trim() === '1';
  } catch {
    // ADB can be offline or unavailable while Windows starts the emulator.
    return false;
  }
}

async function waitForBoot({
  probe,
  isClosed = () => false,
  pause = sleep,
  timeoutMs = 180000,
  intervalMs = 1500
}) {
  const deadline = Date.now() + timeoutMs;
  while (!isClosed()) {
    if (await probe()) return true;
    if (Date.now() >= deadline) throw new Error('Android boot wait timed out');
    await pause(Math.min(intervalMs, Math.max(1, deadline - Date.now())));
  }
  return false;
}

module.exports = { probeAndroidBoot, waitForBoot };
