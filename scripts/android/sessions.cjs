'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const key = session => session.appId + '@' + session.serial;
const readJson = (file, fallback) => {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); }
  catch (error) { if (error.code === 'ENOENT') return fallback; throw error; }
};
function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), {recursive: true});
  const temp = file + '.' + crypto.randomUUID() + '.tmp';
  fs.writeFileSync(temp, JSON.stringify(value, null, 2) + '\n');
  try { fs.renameSync(temp, file); }
  finally { if (fs.existsSync(temp)) fs.unlinkSync(temp); }
}
class Sessions {
  constructor(root, platform) {
    this.root = path.resolve(root);
    this.platform = platform;
    this.file = path.join(this.root, '.ai-apps/android/sessions.json');
  }
  defaults() {
    return {appId: 'muondia', label: 'Muondia', serial: 'emulator-5554',
      avdName: 'AI_APPS_Dev', kind: 'flutter', projectPath: path.join(this.root, 'apps/muondia'),
      packageName: 'com.aiapps.muondia'};
  }
  definitions() {
    const stored = readJson(this.file, {version: 1, sessions: []});
    if (stored.version !== 1 || !Array.isArray(stored.sessions)) throw new Error('Invalid session registry');
    // Registros de proyectos eliminados o de versiones anteriores no pueden
    // bloquear Muondia. La lectura es no destructiva: no se reescribe el JSON.
    const valid = [];
    for (const item of stored.sessions) {
      try {
        valid.push(this.validate(item));
      } catch (error) {
        if (!(error instanceof Error)) throw error;
      }
    }
    return [this.defaults(), ...valid];
  }
  validate(item) {
    const allowed = ['appId','label','serial','avdName','kind','projectPath','packageName'];
    if (!item || Object.keys(item).some(x => !allowed.includes(x)) ||
        typeof item.appId !== 'string' || !/^[a-z0-9][a-z0-9-]*$/.test(item.appId) ||
        item.appId === 'muondia' || typeof item.label !== 'string' || !item.label.trim() ||
        typeof item.serial !== 'string' || !/^[A-Za-z0-9_.:-]+$/.test(item.serial) ||
        item.serial.toLowerCase() === 'emulator-5554' ||
        !['flutter','external'].includes(item.kind) ||
        typeof item.packageName !== 'string' || !/^[A-Za-z][\w]*(?:\.[A-Za-z][\w]*)+$/.test(item.packageName)) {
      throw new Error('Invalid Android session');
    }
    if (item.avdName && (typeof item.avdName !== 'string' || !/^[A-Za-z0-9_-]+$/.test(item.avdName) ||
        item.avdName.toLowerCase() === 'ai_apps_dev')) throw new Error('Reserved or invalid AVD');
    if (item.kind === 'flutter' && (!item.avdName || !path.isAbsolute(item.projectPath || '') ||
        !fs.existsSync(path.join(item.projectPath, 'pubspec.yaml')))) {
      throw new Error('Flutter session requires an existing project and independent AVD');
    }
    return {...item, label: item.label.trim()};
  }
  find(id) {
    const session = this.definitions().find(s => key(s) === id);
    if (!session) throw new Error('Unknown Android session');
    return session;
  }
  register(item) {
    const session = this.validate(item);
    const sessions = this.definitions().slice(1);
    const same = sessions.find(s => key(s) === key(session));
    if (same && JSON.stringify(same) === JSON.stringify(session)) return same;
    if ([this.defaults(), ...sessions].some(s => s.serial === session.serial ||
        (s.avdName && session.avdName && s.avdName.toLowerCase() === session.avdName.toLowerCase()) ||
        key(s) === key(session))) throw new Error('Duplicate device, AVD or application');
    writeJson(this.file, {version: 1, sessions: [...sessions, session]});
    return session;
  }
  async unregister(id) {
    const session = this.find(id);
    if (session.appId === 'muondia') throw new Error('Muondia is reserved');
    if ((await this.platform.devices()).includes(session.serial) &&
        await this.platform.appPid(session)) throw new Error('Stop application before unregistering');
    writeJson(this.file, {version: 1, sessions: this.definitions().slice(1).filter(s => key(s) !== id)});
  }
  async list() {
    const devices = await this.platform.devices();
    return Promise.all(this.definitions().map(async session => {
      const deviceReady = devices.includes(session.serial);
      const appPid = deviceReady ? await this.platform.appPid(session) : '';
      return {...session, id: key(session), deviceReady, appPid,
        active: deviceReady && !!appPid,
        status: !deviceReady ? 'offline' : appPid ? 'running' : 'stopped',
        epoch: String(appPid)};
    }));
  }
}
module.exports = {Sessions, readJson, writeJson, key};
