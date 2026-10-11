// Detached session owner. VS Code only sends requests; it never owns Flutter.
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { Sessions, readJson, writeJson, delay } = require('./sessions.cjs');
const { Windows, runtimeEnv } = require('./windows.cjs');

async function run(root, id, token) {
  const platform = new Windows(root);
  const service = new Sessions(root, platform);
  const session = service.find(id);
  const dir = service.directory(session);
  const leaseFile = service.leaseFile(session);
  const stopFile = path.join(dir, `${token}.stop.json`);
  const stateFile = path.join(dir, 'state.json');
  const state = { status: 'starting', token, pid: process.pid, startedAt: new Date().toISOString() };
  let runner;
  const boot = new AbortController();
  let bootWatcher;
  const ownsLease = () => readJson(leaseFile, null)?.token === token;
  const stopRequested = () => readJson(stopFile, null)?.token === token;
  const save = () => { if (ownsLease()) writeJson(stateFile, state); };
  try {
    // The launcher publishes the worker PID immediately after spawning.
    for (let i = 0; i < 40 && readJson(leaseFile, {})?.pid !== process.pid; i++) await delay(50);
    if (!ownsLease() || readJson(leaseFile, {})?.pid !== process.pid) throw new Error('Lost session lease');
    save();
    bootWatcher = setInterval(() => { if (stopRequested()) boot.abort(); }, 250);
    await platform.prepare(session, boot.signal);
    clearInterval(bootWatcher);
    if (stopRequested()) return;
    const tools = await platform.flutterTools();
    const defines = path.join(dir, 'defines.json');
    writeJson(defines, {});
    do {
      state.status = 'starting'; save();
      runner = spawn(tools.dart, [path.join(root, 'scripts/flutter-dev-runner.dart'),
        '--flutter', tools.flutter, '--device', session.serial, '--defines-file', defines, '--no-dds',
        '--working-directory', session.projectPath, '--watch', session.projectPath], {
        cwd: session.projectPath, windowsHide: true, env: runtimeEnv(), stdio: ['ignore', 'pipe', 'pipe']
      });
      state.runnerPid = runner.pid; save();
      let exit;
      const finished = new Promise(resolve => {
        runner.once('exit', code => { exit = code; resolve(code); });
        runner.once('error', error => { state.error = error.message; exit = 1; resolve(1); });
      });
      let text = '';
      runner.stdout.on('data', bytes => {
        fs.appendFileSync(path.join(dir, 'flutter.stdout.log'), bytes);
        text = (text + bytes.toString()).slice(-4000);
        if (text.includes('Hot reload automatico activo:')) { state.status = 'running'; save(); }
      });
      runner.stderr.on('data', bytes => fs.appendFileSync(path.join(dir, 'flutter.stderr.log'), bytes));
      while (exit === undefined && !stopRequested()) await delay(250);
      if (stopRequested()) {
        state.status = 'stopping'; save();
        await platform.killTree(runner);
        await finished;
        await platform.stopApp(session);
        break;
      }
      await finished;
      if (exit !== 86) throw new Error(`Flutter runner exited (${exit})`);
      await delay(500);
    } while (!stopRequested());
    state.status = 'stopped';
  } catch (error) {
    state.status = stopRequested() ? 'stopped' : 'failed';
    if (!stopRequested()) state.error = String(error.message || error);
    if (runner && runner.exitCode === null) await platform.killTree(runner).catch(() => {});
  } finally {
    clearInterval(bootWatcher);
    if (state.status === 'starting' && stopRequested()) state.status = 'stopped';
    state.finishedAt = new Date().toISOString();
    save();
    if (ownsLease()) fs.unlinkSync(leaseFile);
    if (fs.existsSync(stopFile)) fs.unlinkSync(stopFile);
  }
}
if (require.main === module) run(...process.argv.slice(2)).catch(error => { console.error(error.message); process.exitCode = 1; });
module.exports = { run };
