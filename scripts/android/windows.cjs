const fs = require('node:fs');
const path = require('node:path');
const { spawn, execFile } = require('node:child_process');
const { promisify } = require('node:util');
const execute = promisify(execFile);

function runtimeEnv() {
  const allowed = /^(SYSTEMROOT|WINDIR|COMSPEC|PATH|PATHEXT|TEMP|TMP|USERPROFILE|LOCALAPPDATA|APPDATA|PROGRAMFILES(?:\(X86\))?|HOMEDRIVE|HOMEPATH|ANDROID_HOME|ANDROID_SDK_ROOT|JAVA_HOME|FLUTTER_ROOT)$/i;
  return Object.fromEntries(Object.entries(process.env).filter(([name]) => allowed.test(name)));
}
class Windows {
  constructor(root) {
    this.root = root;
    this.sdk = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT || path.join(process.env.LOCALAPPDATA, 'Android/Sdk');
    this.adb = path.join(this.sdk, 'platform-tools/adb.exe');
  }
  async run(file, args, options = {}) {
    return (await execute(file, args, { windowsHide: true, encoding: 'utf8', timeout: 15000,
      maxBuffer: 4 * 1024 * 1024, ...options })).stdout.trim();
  }
  ps(command, args = []) { return this.run('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', command, ...args]); }
  async devices() {
    const text = await this.run(this.adb, ['devices']);
    return text.split(/\r?\n/).filter(line => /^\S+\s+device\s*$/.test(line)).map(line => line.split(/\s+/)[0]);
  }
  async appPid(session) {
    try { return await this.run(this.adb, ['-s', session.serial, 'shell', 'pidof', session.packageName]); }
    catch { return ''; }
  }
  async taskRunning() {
    try { return (await this.ps("(Get-ScheduledTask -TaskName 'AI-APPS Development' -ErrorAction Stop).State")) === 'Running'; }
    catch { return false; }
  }
  startTask() { return this.ps("Start-ScheduledTask -TaskName 'AI-APPS Development'"); }
  stopTask() {
    return this.run('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
      '-File', path.join(this.root, 'scripts/android/task-control.ps1'), '-Action', 'Stop', '-RepoRoot', this.root], { timeout: 30000 });
  }
  async hasFlutter(session) {
    const result = await this.run('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
      '-File', path.join(this.root, 'scripts/android/task-control.ps1'), '-Action', 'Check', '-Serial', session.serial]);
    return result === 'busy';
  }
  spawnWorker(id, token, dir) {
    const out = fs.openSync(path.join(dir, 'worker.stdout.log'), 'a');
    const err = fs.openSync(path.join(dir, 'worker.stderr.log'), 'a');
    try {
      const worker = spawn(process.execPath, [path.join(this.root, 'scripts/android/worker.cjs'), this.root, id, token], {
        cwd: dir, env: { ...runtimeEnv(), ELECTRON_RUN_AS_NODE: '1' },
        detached: true, windowsHide: true, stdio: ['ignore', out, err]
      });
      worker.unref();
      worker.on('error', () => {}); // Startup state/lease allow diagnosis without an unhandled event.
      if (!worker.pid) throw new Error('Could not spawn session worker');
      return worker.pid;
    } finally { fs.closeSync(out); fs.closeSync(err); }
  }
  async prepare(session, signal) {
    await this.run('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
      '-File', path.join(this.root, 'scripts/start-ai-apps-android.ps1'),
      '-AvdName', session.avdName, '-Serial', session.serial], { timeout: 200000, env: runtimeEnv(), signal });
  }
  async flutterTools() {
    const flutter = await this.ps('(Get-Command flutter -ErrorAction Stop).Source');
    const dart = path.join(path.dirname(flutter), 'cache/dart-sdk/bin/dart.exe');
    if (!fs.existsSync(dart)) throw new Error('Dart runtime missing from Flutter');
    return { flutter, dart };
  }
  async killTree(child) {
    if (child.exitCode !== null) return;
    await this.run('taskkill.exe', ['/PID', String(child.pid), '/T', '/F']).catch(error => {
      if (child.exitCode === null) throw error;
    });
  }
  async stopApp(session) {
    await this.run(this.adb, ['-s', session.serial, 'shell', 'am', 'force-stop', session.packageName]);
  }
}
module.exports = { Windows, runtimeEnv };
