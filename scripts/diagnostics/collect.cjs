'use strict';
// Share a bounded operational projection, never raw host logs or Gradle HTML.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const MAX_REPORT_BYTES = 8 * 1024 * 1024;
function safeLabel(input) {
  if (typeof input !== 'string') return '';
  const s = input.normalize('NFC').trim();
  if (!s || s.length > 160 || !/^[\p{L}\p{N}\s_.:\-()]+$/u.test(s) ||
      /password|passwd|token|secret|credential|api.?key|authorization|bearer/i.test(s)) return '';
  return s;
}
function problemIds(payload) {
  const counts = new Map();
  let nodes = 0;
  function visit(node, depth) {
    if (!node || typeof node !== 'object' || depth > 24 || ++nodes > 30000) return;
    if (Array.isArray(node)) {
      for (const child of node.slice(0, 2000)) visit(child, depth + 1);
      return;
    }
    const id = node.problemId;
    if (id && typeof id === 'object' && !Array.isArray(id)) {
      const name = safeLabel(id.name);
      const displayName = safeLabel(id.displayName);
      const severity = ['ERROR', 'WARNING', 'ADVICE'].includes(node.severity) ?
        node.severity : 'UNSPECIFIED';
      if (name || displayName) {
        const key = JSON.stringify([name, displayName, severity]);
        counts.set(key, (counts.get(key) || 0) + 1);
      }
    }
    for (const [key, value] of Object.entries(node).slice(0, 250)) {
      if (key !== 'problemId') visit(value, depth + 1);
    }
  }
  visit(payload, 0);
  return counts;
}
function gradle(root) {
  const candidates = [
    'build/reports/problems/problems-report.html',
    'apps/muondia/build/reports/problems/problems-report.html',
    'apps/muondia/android/build/reports/problems/problems-report.html'
  ];
  const reports = [];
  for (const relative of candidates) {
    const file = path.join(root, ...relative.split('/'));
    let st;
    try { st = fs.lstatSync(file); }
    catch (error) { if (error.code === 'ENOENT') continue; throw error; }
    if (!st.isFile() || st.isSymbolicLink()) continue;
    const report = { source: relative, bytes: st.size };
    if (st.size > MAX_REPORT_BYTES) {
      report.extraction = 'report_too_large';
      reports.push(report);
      continue;
    }
    const bytes = fs.readFileSync(file);
    report.sha256 = crypto.createHash('sha256').update(bytes).digest('hex');
    const html = bytes.toString('utf8');
    const counts = new Map();
    const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)].slice(0, 100);
    for (const [, attrs, body] of scripts) {
      if (!/\btype\s*=\s*['"]application\/json['"]/i.test(attrs) ||
          body.length > MAX_REPORT_BYTES) continue;
      try {
        for (const [key, n] of problemIds(JSON.parse(body))) {
          counts.set(key, (counts.get(key) || 0) + n);
        }
      } catch { /* Unsupported report layout: publish metadata, not raw text. */ }
    }
    if (!counts.size) {
      // Some Gradle releases embed problemId fragments inside JavaScript.
      for (const match of html.matchAll(/"problemId"\s*:\s*\{([^{}]{0,1200})\}/g)) {
        const id = safeLabel(/"name"\s*:\s*"([^"\\]{1,160})"/.exec(match[1])?.[1]);
        const display = safeLabel(/"displayName"\s*:\s*"([^"\\]{1,160})"/.exec(match[1])?.[1]);
        if (!id && !display) continue;
        const key = JSON.stringify([id, display, 'UNSPECIFIED']);
        counts.set(key, (counts.get(key) || 0) + 1);
        if (counts.size >= 500) break;
      }
    }
    report.issues = [...counts.entries()].map(([key, occurrences]) => {
      const [id, displayName, severity] = JSON.parse(key);
      return { id, displayName, severity, occurrences };
    }).sort((a, b) => [a.id, a.displayName, a.severity].join('|')
      .localeCompare([b.id, b.displayName, b.severity].join('|'), 'en')).slice(0, 40);
    report.extraction = report.issues.length ? 'problem_ids' : 'metadata_only';
    reports.push(report);
  }
  return reports;
}
const knownEvents = {
  'dev-session.log': [
    [/Sincronizacion continua de dev solicitada\./, 'sync_requested'],
    [/Sincronizacion no iniciada:/, 'sync_start_error'],
    [/Android preparado:/, 'android_ready'],
    [/Muondia preparado;/, 'muondia_ready'],
    [/Sesion Flutter terminada\./, 'flutter_stopped'],
    [/ERROR en Sincronizacion:/, 'sync_start_error'],
    [/ERROR en Android:/, 'android_error'],
    [/ERROR en Muondia:/, 'muondia_error']
  ],
  'auto-sync-dev.log': [
    [/Continuous dev sync started\./, 'sync_started'],
    [/Remote changes applied automatically:/, 'remote_applied'],
    [/Local changes committed automatically\./, 'local_committed'],
    [/Local auto-sync failed:/, 'local_sync_error'],
    [/Fetch failed:/, 'fetch_error'],
    [/Fast-forward failed:/, 'merge_error'],
    [/Push failed:|Push after rebase failed:/, 'push_error'],
    [/rebase conflicted|Rebase conflict/, 'rebase_conflict'],
    [/Auto-sync stopped:/, 'sync_stopped'],
    [/Auto-sync not started:/, 'wrong_branch'],
    [/Diagnostics exporter unavailable\./, 'diagnostics_error']
  ]
};
function events(root, name) {
  const file = path.join(root, '.ai-apps', name);
  let size;
  try { size = fs.statSync(file).size; }
  catch (e) { if (e.code === 'ENOENT') return { available: false, events: [] }; throw e; }
  const fd = fs.openSync(file, 'r');
  let buffer;
  try {
    buffer = Buffer.alloc(Math.min(size, 48 * 1024));
    fs.readSync(fd, buffer, 0, buffer.length, Math.max(0, size - buffer.length));
  } finally { fs.closeSync(fd); }
  const result = [];
  for (const line of buffer.toString('utf8').split(/\r?\n/).slice(-200)) {
    const found = knownEvents[name].find(([re]) => re.test(line));
    if (found && result.at(-1) !== found[1]) result.push(found[1]);
  }
  return { available: true, events: result.slice(-12) };
}
function collect(root, now = new Date()) {
  root = path.resolve(root);
  if (!fs.existsSync(path.join(root, 'AGENTS.md'))) throw Error('Not AI-APPS');
  const snapshot = {
    schema: 1,
    purpose: 'Private operational diagnostics, never raw system logs',
    checkedUtcHour: now.toISOString().slice(0, 13) + ':00Z',
    gradle: gradle(root),
    development: events(root, 'dev-session.log'),
    synchronization: events(root, 'auto-sync-dev.log')
  };
  const target = path.join(root, 'diagnostics', 'current.json');
  const content = JSON.stringify(snapshot, null, 2) + '\n';
  if (fs.existsSync(target) && fs.readFileSync(target, 'utf8') === content) {
    return { changed: false, file: target };
  }
  fs.mkdirSync(path.dirname(target), { recursive: true });
  const temporary = target + '.' + process.pid + '.tmp';
  try { fs.writeFileSync(temporary, content, { mode: 0o600 }); fs.renameSync(temporary, target); }
  finally { if (fs.existsSync(temporary)) fs.unlinkSync(temporary); }
  return { changed: true, file: target };
}
if (require.main === module) {
  try { collect(process.argv[2] || process.cwd()); }
  catch (error) {
    console.error('Diagnostics collection failed (' + (error.code || error.name) + ')');
    process.exitCode = 1;
  }
}
module.exports = { collect, gradle, events, safeLabel };
