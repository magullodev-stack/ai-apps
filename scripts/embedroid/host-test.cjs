// Run with --extensionTestsPath in a separate VS Code profile. This opens
// real webviews on the existing device, without activating AI-APPS startup.
const vscode = require('vscode');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const runtime = path.resolve(__dirname, '../../.ai-apps/embedroid');
const profile = path.join(runtime, 'host-profile');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
function emulatorLogs(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) return emulatorLogs(file);
    return entry.name.endsWith('-Android Emulator.log') ? [file] : [];
  });
}

exports.run = async () => {
  const report = { passed: false, cycles: [] };
  try {
    const extension = vscode.extensions.getExtension('magullodev.ai-apps-embedroid');
    assert.ok(extension, 'Maintained extension loaded');
    assert.ok(!vscode.extensions.getExtension('utpalbarman.embedroid'), 'No duplicate original extension');
    report.extensionPath = extension.extensionPath;
    await extension.activate();
    const commands = await vscode.commands.getCommands(true);
    assert.ok(commands.includes('embedroid.openEmbedded'));
    await vscode.workspace.getConfiguration('embedroid').update('sdkPath',
      path.join(process.env.LOCALAPPDATA, 'Android/Sdk'), vscode.ConfigurationTarget.Global);
    for (let cycle = 1; cycle <= 2; cycle++) {
      const initialText = emulatorLogs(path.join(profile, 'logs')).map(file => fs.readFileSync(file, 'utf8')).join('\n');
      const baseline = (initialText.match(/streaming established on attempt 1/g) || []).length;
      await vscode.commands.executeCommand('embedroid.openEmbedded', { device: { serial: 'emulator-5554' } });
      const deadline = Date.now() + 20000;
      let text;
      while (Date.now() < deadline) {
        text = emulatorLogs(path.join(profile, 'logs')).map(file => fs.readFileSync(file, 'utf8')).join('\n');
        if ((text.match(/streaming established on attempt 1/g) || []).length > baseline) break;
        await delay(200);
      }
      assert.ok((text.match(/streaming established on attempt 1/g) || []).length > baseline, 'Real webview receives H.264');
      await delay(10000);
      text = emulatorLogs(path.join(profile, 'logs')).map(file => fs.readFileSync(file, 'utf8')).join('\n');
      assert.ok(!/NumberFormatException|ERROR|launch attempt .* failed/.test(text), text);
      const tabs = vscode.window.tabGroups.all.flatMap(group => group.tabs).filter(tab =>
        tab.input instanceof vscode.TabInputWebview && tab.input.viewType.endsWith('embedroid.embedded'));
      assert.equal(tabs.length, 1);
      await vscode.window.tabGroups.close(tabs, true);
      report.cycles.push({ cycle, establishedOnAttempt: 1, sustainedSeconds: 10 });
    }
    report.passed = true;
  } catch (error) {
    report.error = error.stack;
    throw error;
  } finally {
    fs.writeFileSync(path.join(runtime, 'host-test-result.json'), JSON.stringify(report, null, 2));
  }
};
