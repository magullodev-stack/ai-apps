const vscode = require('vscode');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const runtime = path.resolve(__dirname, '../../.ai-apps/android-host');
const phase = Number(fs.readFileSync(path.join(runtime, 'phase.txt'), 'utf8'));
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(check, message, timeout = 45000) {
  const end = Date.now() + timeout;
  while (Date.now() < end) { if (await check()) return; await delay(200); }
  throw new Error(message);
}
function tabs() {
  return vscode.window.tabGroups.all.flatMap(group => group.tabs).filter(tab =>
    tab.input instanceof vscode.TabInputWebview && tab.input.viewType.endsWith('embedroid.embedded'));
}
exports.run = async () => {
  const report = { passed: false, phase };
  try {
    const api = await vscode.extensions.getExtension('magullodev.ai-apps-android').activate();
    const viewer = await vscode.extensions.getExtension('magullodev.ai-apps-embedroid').activate();
    assert.ok(api, 'Integration activated on a trusted AI-APPS workspace');
    await api.refresh();
    await until(() => viewer.listSessions().length === 2 && viewer.listSessions().every(item => item.videoFrames > 0),
      'Both real webviews must render H.264 video');
    assert.equal(tabs().length, 2);
    report.initial = viewer.listSessions();
    await api.refresh(); await api.refresh();
    assert.equal(tabs().length, 2, 'Automatic recovery and polling do not duplicate tabs');
    const session = api.list().find(item => item.appId === 'lab-validation');
    assert.ok(session?.active, 'Second Flutter app is running');
    const primary = tabs().find(tab => tab.label === 'QuizAI · emulator-5554');
    assert.ok(primary);
    await vscode.commands.executeCommand('aiAppsAndroid.reconnect', session);
    await until(() => viewer.listSessions().find(item => item.appId === 'lab-validation')?.lastFrameAt > Date.now() - 1500,
      'Target reconnection renders video');
    assert.ok(tabs().includes(primary), 'Reconnect preserves the other panel instance');
    const labTab = tabs().find(tab => tab.label === 'Lab validation · emulator-5556');
    await vscode.window.tabGroups.close(labTab, true);
    await delay(1000); await api.refresh();
    assert.equal(tabs().length, 1, 'User tab close does not restart/reopen the active app');
    assert.ok(api.list().find(item => item.appId === 'lab-validation').active, 'Flutter remains alive after tab close');
    await vscode.commands.executeCommand('aiAppsAndroid.open', session);
    await until(() => viewer.listSessions().length === 2 && viewer.listSessions().every(item => item.videoFrames > 0),
      'Reopening the target preserves both videos');
    const first = viewer.listSessions().find(item => item.appId === 'lab-validation').videoFrames;
    await delay(6000);
    assert.ok(viewer.listSessions().find(item => item.appId === 'lab-validation').videoFrames > first,
      'Real rendered frames continue after reopening');
    assert.equal(tabs().length, 2);
    report.restoredPanels = viewer.restoredCount();
    if (phase === 2) assert.ok(report.restoredPanels > 0, 'Second editor process actually deserialized persisted webviews');
    report.final = viewer.listSessions(); report.passed = true;
  } catch (error) { report.error = error.stack; throw error; }
  finally { fs.writeFileSync(path.join(runtime, `result-${phase}.json`), JSON.stringify(report, null, 2)); }
  // Close the isolated window normally so editor state/webview identity is saved.
  await vscode.commands.executeCommand('workbench.action.closeWindow');
};
