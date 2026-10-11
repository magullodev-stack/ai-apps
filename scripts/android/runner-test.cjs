const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { Windows } = require('./windows.cjs');

async function run() {
  const root = path.resolve(__dirname, '../..');
  const dir = path.join(root, '.ai-apps/runner-test');
  fs.mkdirSync(dir, { recursive: true });
  const { dart } = await new Windows(root).flutterTools();
  const capture = path.join(dir, 'args.json');
  const fake = path.join(dir, 'fake-flutter.cjs');
  fs.writeFileSync(fake, `require('node:fs').writeFileSync(${JSON.stringify(capture)},JSON.stringify(process.argv.slice(2)));`);
  const batch = path.join(dir, 'fake-flutter.bat');
  fs.writeFileSync(batch, `@echo off\r\n"${process.execPath}" "${fake}" %*\r\n`);
  const defines = path.join(dir, 'defines.json'); fs.writeFileSync(defines, '{}');
  const base = [path.join(root, 'scripts/flutter-dev-runner.dart'), '--flutter', batch,
    '--device', 'test-device', '--working-directory', dir, '--defines-file', defines, '--watch', dir];
  const options = { cwd: dir, windowsHide: true, encoding: 'utf8', env: { ...process.env, ELECTRON_RUN_AS_NODE: '1' }, timeout: 30000 };
  execFileSync(dart, base, options);
  const original = JSON.parse(fs.readFileSync(capture));
  assert.deepEqual(original, ['run', '--machine', '-d', 'test-device', `--dart-define-from-file=${defines}`],
    'Default invocation stays byte-for-byte compatible with QuizAI');
  execFileSync(dart, [...base, '--no-dds'], options);
  const managed = JSON.parse(fs.readFileSync(capture));
  assert.deepEqual(managed, ['run', '--machine', '--no-dds', '-d', 'test-device', `--dart-define-from-file=${defines}`]);
  console.log('PASS: actual Dart runner, legacy default arguments unchanged, managed no-dds option and per-device machine mode.');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
