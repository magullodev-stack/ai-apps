'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { collect } = require('./collect.cjs');
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ai-apps-diagnostics-'));
try {
  fs.writeFileSync(path.join(root, 'AGENTS.md'), '# AI-APPS');
  const write = (name, value) => {
    const target = path.join(root, name);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, value);
  };
  const report = {
    diagnostics: [
      { problemId: { name: 'deprecated-api', displayName: 'Deprecated Gradle API' },
        severity: 'WARNING', contextualLabel: 'C:\\Users\\Someone\\private.txt password=123' },
      { problemId: { name: 'deprecated-api', displayName: 'Deprecated Gradle API' },
        severity: 'WARNING' },
      { problemId: { name: 'api-key-sk_12345678901234567890',
        displayName: 'password is xyz' }, severity: 'ERROR' }
    ]
  };
  write('build/reports/problems/problems-report.html',
    '<html><script type="application/json">' + JSON.stringify(report) + '</script></html>');
  write('.ai-apps/dev-session.log',
    '[time] Muondia preparado; hot reload automatico activo. password=12345\n');
  write('.ai-apps/auto-sync-dev.log',
    '[time] Fetch failed: https://secret.example.com/sk-verysecret\n');
  // Regression: the executable must create its file even if the embedded
  // Node host does not identify the collector module as require.main.
  const cliRoot = path.join(root, 'cli-test');
  fs.mkdirSync(cliRoot);
  fs.writeFileSync(path.join(cliRoot, 'AGENTS.md'), '# AI-APPS');
  const run = spawnSync(process.execPath,
    [path.join(__dirname, 'collect-cli.cjs'), cliRoot],
    { encoding: 'utf8', env: { ...process.env, ELECTRON_RUN_AS_NODE: '1' }, timeout: 15000 });
  assert.equal(run.status, 0, 'CLI must succeed: ' + (run.stderr || 'no stderr'));
  assert.match(run.stdout, /DIAGNOSTICS_COLLECTED/);
  assert.ok(fs.statSync(path.join(cliRoot, 'diagnostics/current.json')).isFile(),
    'CLI must create diagnostics/current.json without require.main');

  const timestamp = new Date('2026-10-13T13:23:00Z');
  assert.equal(collect(root, timestamp).changed, true);
  assert.equal(collect(root, timestamp).changed, false, 'No redundant commits in the same hour');
  const snapshot = fs.readFileSync(path.join(root, 'diagnostics/current.json'), 'utf8');
  const data = JSON.parse(snapshot);
  assert.equal(data.gradle.length, 1);
  assert.deepEqual(data.gradle[0].issues, [
    { id: 'deprecated-api', displayName: 'Deprecated Gradle API',
      severity: 'WARNING', occurrences: 2 }
  ]);
  assert.deepEqual(data.development.events, ['muondia_ready']);
  assert.deepEqual(data.synchronization.events, ['fetch_error']);
  for (const forbidden of ['Someone', 'private.txt', 'password', 'secret', 'C:', 'https:', 'sk-']) {
    assert.ok(!snapshot.includes(forbidden), 'No private data: ' + forbidden);
  }
  assert.equal(collect(root, new Date('2026-10-13T14:05:00Z')).changed, true,
    'Hourly update demonstrates publisher liveness');
  write('apps/muondia/build/reports/problems/problems-report.html', '<html>Unknown layout</html>');
  assert.equal(collect(root, new Date('2026-10-13T14:05:00Z')).changed, true);
  assert.equal(JSON.parse(fs.readFileSync(path.join(root, 'diagnostics/current.json')))
    .gradle[1].extraction, 'metadata_only');
  console.log('PASS: private diagnostic projection, Gradle identifiers, safe events and idempotence.');
} finally {
  fs.rmSync(root, { recursive: true, force: true });
}
