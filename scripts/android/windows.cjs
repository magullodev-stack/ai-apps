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
    const { stdout } = await execute(file, args, { windowsHide: true, encoding: 'utf8', timeout: 15000,
      maxBuffer: 4 * 1024 * 1024, ...options });
    return Buffer.isBuffer(stdout) ? stdout : stdout.trim();
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
  async screenOwner(session) {
    const [appPid, focus, activity, avdName, bootId] = await Promise.all([
      this.appPid(session),
      this.run(this.adb, ['-s', session.serial, 'shell', 'dumpsys', 'window', 'displays']),
      this.run(this.adb, ['-s', session.serial, 'shell', 'dumpsys', 'activity', 'activities']),
      this.run(this.adb, ['-s', session.serial, 'shell', 'getprop', 'ro.boot.qemu.avd_name']),
      this.run(this.adb, ['-s', session.serial, 'shell', 'cat', '/proc/sys/kernel/random/boot_id'])
    ]);
    const defaultDisplay = /Display:\s*mDisplayId=0\b[\s\S]*?(?=\r?\n\s*Display:\s*mDisplayId=|$)/.exec(focus)?.[0] || '';
    const defaultActivities = /Display #0\b[\s\S]*?(?=\r?\n\s*Display #|$)/.exec(activity)?.[0] || '';
    const focusedPackage = /mCurrentFocus=Window\{[^\r\n]*?\s([A-Za-z][\w.]*)\//.exec(defaultDisplay)?.[1];
    const resumedPackage = /(?:topResumedActivity|mResumedActivity)[^\r\n]*?\s([A-Za-z][\w.]*)\//.exec(defaultActivities)?.[1];
    if (!appPid || focusedPackage !== session.packageName || resumedPackage !== session.packageName ||
        avdName.toLowerCase() !== session.avdName.toLowerCase() || !bootId) {
      throw new Error('Experiment application is not the focused/resumed owner of its AVD');
    }
    return { appPid, focusedPackage, resumedPackage, avdName, bootId, displayId: 0 };
  }
  async capture(session) {
    const before = await this.screenOwner(session);
    const bytes = await this.run(this.adb, ['-s', session.serial, 'exec-out', 'screencap', '-p'], {
      windowsHide: true, encoding: 'buffer', timeout: 15000, maxBuffer: 16 * 1024 * 1024, env: runtimeEnv()
    });
    const after = await this.screenOwner(session);
    if (JSON.stringify(before) !== JSON.stringify(after)) throw new Error('Screen owner changed during capture');
    return { bytes, before, after };
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
  async retireAvd(session) {
    // Lab AVDs are uniquely named from the immutable experiment SHA.
    if (!/^AI_APPS_Lab_[a-f0-9]{12}$/.test(session.avdName) ||
        session.serial === 'emulator-5554') throw new Error('Protected Android device');
    const root = process.env.ANDROID_AVD_HOME ||
      path.join(process.env.USERPROFILE, '.android', 'avd');
    const folder = path.join(root, session.avdName + '.avd');
    const ini = path.join(root, session.avdName + '.ini');
    // Shut down only this lab emulator, never the AI-APPS_Dev device.
    const devices = await this.devices();
    if (devices.includes(session.serial)) {
      await this.run(this.adb, ['-s', session.serial, 'emu', 'kill']).catch(() => {});
      for (let i = 0; i < 30 && (await this.devices()).includes(session.serial); i++) {
        await new Promise(resolve => setTimeout(resolve, 500));
      }
      if ((await this.devices()).includes(session.serial)) {
        throw new Error('Lab emulator is still running; AVD and experiment preserved');
      }
    }
    for (const file of [folder, ini]) {
      if (!fs.existsSync(file)) continue;
      if (fs.lstatSync(file).isSymbolicLink()) throw new Error('AVD is a link; refusing to delete');
      fs.rmSync(file, { recursive: true, force: true });
    }
  }
  async stopApp(session) {
    await this.run(this.adb, ['-s', session.serial, 'shell', 'am', 'force-stop', session.packageName]);
  }
}
module.exports = { Windows, runtimeEnv };
