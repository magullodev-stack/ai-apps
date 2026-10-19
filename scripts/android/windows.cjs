'use strict';
const path = require('node:path');
const {execFile} = require('node:child_process');
const {promisify} = require('node:util');
const execute = promisify(execFile);
class Windows {
  constructor(root) {
    this.root = root;
    const sdk = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT ||
      path.join(process.env.LOCALAPPDATA || '', 'Android/Sdk');
    this.adb = path.join(sdk, 'platform-tools/adb.exe');
  }
  async run(file, args, options = {}) {
    const {stdout} = await execute(file, args, {windowsHide: true,
      encoding: 'utf8', timeout: 15000, maxBuffer: 4 * 1024 * 1024, ...options});
    return stdout.trim();
  }
  async devices() {
    const lines = await this.run(this.adb, ['devices']);
    return lines.split(/\r?\n/).filter(line => /^\S+\s+device\s*$/.test(line))
      .map(line => line.trim().split(/\s+/)[0]);
  }
  async appPid(session) {
    try { return await this.run(this.adb, ['-s', session.serial, 'shell', 'pidof', session.packageName]); }
    catch { return ''; }
  }
}
module.exports = {Windows};
