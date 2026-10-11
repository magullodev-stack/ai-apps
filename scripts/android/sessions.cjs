const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

function readJson(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); }
  catch (error) { if (error.code === 'ENOENT') return fallback; throw error; }
}
function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const temporary = `${file}.${crypto.randomUUID()}.tmp`;
  fs.writeFileSync(temporary, JSON.stringify(value, null, 2) + '\n', { mode: 0o600 });
  try {
    for (let attempt = 0; ; attempt++) {
      try { fs.renameSync(temporary, file); break; }
      catch (error) {
        if (!['EPERM', 'EACCES', 'EBUSY'].includes(error.code) || attempt >= 30) throw error;
        // Windows scanners/readers can hold the destination briefly. Keep the
        // atomic replacement; never unlink the current state as a workaround.
        Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 20);
      }
    }
  } finally { if (fs.existsSync(temporary)) fs.unlinkSync(temporary); }
}
function alive(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try { process.kill(pid, 0); return true; } catch { return false; }
}
function key(session) { return `${session.appId}@${session.serial}`; }
function sameAvd(a, b) { return !!a.avdName && !!b.avdName && a.avdName.toLowerCase() === b.avdName.toLowerCase(); }
class Sessions {
  constructor(root, platform) {
    this.root = path.resolve(root);
    this.platform = platform;
    this.runtime = path.join(this.root, '.ai-apps/android');
    this.file = path.join(this.runtime, 'sessions.json');
  }
  defaults() {
    return { appId: 'quizai', label: 'QuizAI', serial: 'emulator-5554', avdName: 'AI_APPS_Dev',
      kind: 'development-task', projectPath: path.join(this.root, 'apps/quizai'), packageName: 'com.aiapps.quizai' };
  }
  definitions() {
    const stored = readJson(this.file, { version: 1, sessions: [] });
    if (stored.version !== 1 || !Array.isArray(stored.sessions)) throw new Error('Invalid Android session registry');
    const sessions = [this.defaults()];
    for (const item of stored.sessions) {
      const session = this.validate(item);
      if (sessions.some(previous => key(previous) === key(session) || previous.serial === session.serial ||
          sameAvd(previous, session))) throw new Error('Duplicate Android application/device or AVD');
      sessions.push(session);
    }
    return sessions;
  }
  validate(item) {
    const allowed = ['appId', 'label', 'serial', 'avdName', 'kind', 'projectPath', 'packageName'];
    if (!item || Object.keys(item).some(name => !allowed.includes(name)) ||
        typeof item.appId !== 'string' || !/^[a-z0-9][a-z0-9-]*$/.test(item.appId) || item.appId === 'quizai' ||
        typeof item.label !== 'string' || !item.label.trim() || item.label.length > 100 ||
        /[\r\n\x00]/.test(item.label) || typeof item.serial !== 'string' || !/^[A-Za-z0-9_.:-]+$/.test(item.serial) ||
        item.serial.toLowerCase() === 'emulator-5554' || !['flutter', 'external'].includes(item.kind) ||
        !/^[a-zA-Z][\w]*(?:\.[a-zA-Z][\w]*)+$/.test(item.packageName || '')) {
      throw new Error('Invalid session; QuizAI and emulator-5554 are reserved for AI-APPS Development');
    }
    if (item.avdName && (typeof item.avdName !== 'string' || !/^[A-Za-z0-9_-]+$/.test(item.avdName) || item.avdName.toLowerCase() === 'ai_apps_dev')) throw new Error('Invalid or reserved AVD');
    if (item.kind === 'flutter') {
      const port = Number(/^emulator-(\d+)$/.exec(item.serial)?.[1]);
      if (!item.avdName || port < 5556 || port > 5682 || port % 2 || !port) throw new Error('Select an independent AVD and an even emulator console port (5556..5682)');
      if (typeof item.projectPath !== 'string' || !path.isAbsolute(item.projectPath)) throw new Error('Flutter projectPath must be absolute');
    }
    return { ...item, label: item.label.trim() };
  }
  register(item) {
    const session = this.validate(item);
    fs.mkdirSync(this.runtime, { recursive: true });
    const lock = path.join(this.runtime, 'registry.lock');
    // Registration is a short transaction shared by CLI and editor instances.
    let handle;
    try { handle = fs.openSync(lock, 'wx'); }
    catch (error) {
      if (error.code !== 'EEXIST') throw error;
      if (alive(readJson(lock, {}).pid)) throw new Error('Another registration is in progress');
      fs.unlinkSync(lock);
      handle = fs.openSync(lock, 'wx');
    }
    fs.writeFileSync(handle, JSON.stringify({ pid: process.pid }));
    try {
      const all = this.definitions();
      const previous = all.find(entry => key(entry) === key(session));
      if (previous && JSON.stringify(previous) === JSON.stringify(session)) return previous;
      if (all.some(entry => entry.serial === session.serial || sameAvd(entry, session))) throw new Error('Device or AVD already registered');
      writeJson(this.file, { version: 1, sessions: [...all.slice(1), session] });
      return session;
    } finally { fs.closeSync(handle); fs.unlinkSync(lock); }
  }
  find(id) {
    const session = this.definitions().find(item => key(item) === id);
    if (!session) throw new Error('Unknown Android application/device session');
    return session;
  }
  directory(session) { return path.join(this.runtime, 'sessions', `${session.appId}@${encodeURIComponent(session.serial)}`); }
  leaseFile(session) { return path.join(this.directory(session), 'lease.json'); }
  state(session) { return readJson(path.join(this.directory(session), 'state.json'), { status: 'stopped' }); }
  async list() {
    const devices = await this.platform.devices();
    return Promise.all(this.definitions().map(async session => {
      const deviceReady = devices.includes(session.serial);
      const pid = deviceReady ? await this.platform.appPid(session) : '';
      const state = this.state(session);
      const lease = readJson(this.leaseFile(session), null);
      const runnerAlive = !!lease && alive(lease.pid);
      const taskRunning = session.kind === 'development-task' && await this.platform.taskRunning();
      const active = deviceReady && !!pid && (session.kind !== 'flutter' || runnerAlive);
      let status = active ? 'running' : deviceReady ? 'device_ready' : 'offline';
      if (session.kind === 'flutter' && runnerAlive && state.status !== 'running') status = state.status;
      if (session.kind === 'development-task' && taskRunning && !active) status = 'starting';
      if (session.kind === 'flutter' && !runnerAlive && ['failed', 'starting', 'running'].includes(state.status)) status = 'failed';
      return { ...session, id: key(session), deviceReady, active, status, appPid: pid,
        epoch: `${state.token || ''}:${pid}` };
    }));
  }
  async start(id) {
    const session = this.find(id);
    if (session.kind === 'development-task') {
      if (await this.platform.taskRunning()) return;
      if (await this.platform.hasFlutter(session)) throw new Error('QuizAI already has a Flutter runner outside the task; recover it before starting');
      await this.platform.startTask(); return;
    }
    if (session.kind === 'external') throw new Error('External sessions are controlled by their owner; only visualization is managed here');
    if (!fs.existsSync(path.join(session.projectPath, 'pubspec.yaml'))) throw new Error('Flutter project is missing pubspec.yaml');
    const dir = this.directory(session);
    fs.mkdirSync(dir, { recursive: true });
    const leaseFile = this.leaseFile(session);
    let handle;
    try { handle = fs.openSync(leaseFile, 'wx'); }
    catch (error) {
      if (error.code !== 'EEXIST') throw error;
      const previous = readJson(leaseFile, {});
      if (alive(previous.pid) || alive(previous.launcherPid)) return;
      // Never start a second Flutter after an unclean worker exit.
      if (await this.platform.hasFlutter(session)) throw new Error('An existing Flutter runner owns this device; stop/recover it before starting');
      fs.unlinkSync(leaseFile);
      return this.start(id);
    }
    const token = crypto.randomUUID();
    fs.writeFileSync(handle, JSON.stringify({ token, launcherPid: process.pid, pid: null }));
    fs.closeSync(handle);
    writeJson(path.join(dir, 'state.json'), { status: 'starting', token, startedAt: new Date().toISOString() });
    try {
      if (await this.platform.hasFlutter(session)) throw new Error('Another Flutter runner is using this device');
      const pid = this.platform.spawnWorker(id, token, dir);
      writeJson(leaseFile, { token, pid, launcherPid: null });
    } catch (error) {
      fs.unlinkSync(leaseFile);
      writeJson(path.join(dir, 'state.json'), { status: 'failed', token, error: String(error.message) });
      throw error;
    }
  }
  async stop(id) {
    const session = this.find(id);
    if (session.kind === 'development-task') { await this.platform.stopTask(); return; }
    if (session.kind === 'external') throw new Error('External session: stop it through its owner');
    const lease = readJson(this.leaseFile(session), null);
    if (!lease) return;
    if (!alive(lease.pid)) throw new Error('Worker is not alive; refuse to kill an unverified process');
    const dir = this.directory(session);
    writeJson(path.join(dir, `${lease.token}.stop.json`), { token: lease.token });
    for (let attempt = 0; attempt < 840; attempt++) {
      if (readJson(this.leaseFile(session), null)?.token !== lease.token) return;
      await delay(250);
    }
    throw new Error('Session did not acknowledge stop; inspect its private logs');
  }
}
module.exports = { Sessions, readJson, writeJson, alive, key, delay };
