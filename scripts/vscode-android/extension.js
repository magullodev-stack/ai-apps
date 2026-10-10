const vscode = require('vscode');
const fs = require('fs');
const path = require('path');

const EMBEDROID_ID = 'utpalbarman.embedroid';
const output = vscode.window.createOutputChannel('AI-APPS Android');

function getWorkspace() {
  return (vscode.workspace.workspaceFolders || []).find(folder => {
    const root = folder.uri.fsPath;
    return (
      path.basename(root).toLowerCase() === 'ai-apps' &&
      fs.existsSync(path.join(root, 'AGENTS.md'))
    );
  });
}

async function openEmbeDroid(folder, serial) {
  const extension = vscode.extensions.getExtension(EMBEDROID_ID);
  if (!extension) {
    throw new Error('EmbeDroid no está instalado.');
  }

  await extension.activate();

  const config = vscode.workspace.getConfiguration('embedroid', folder.uri);
  await config.update('openIn', 'active', vscode.ConfigurationTarget.Workspace);
  await config.update('headless', true, vscode.ConfigurationTarget.Workspace);

  const alreadyOpen = vscode.window.tabGroups.all.some(group =>
    group.tabs.some(tab =>
      tab.input instanceof vscode.TabInputWebview &&
      tab.input.viewType === 'embedroid.embedded'
    )
  );

  if (!alreadyOpen) {
    await vscode.commands.executeCommand('embedroid.openEmbedded', {
      device: { serial }
    });
  }

  output.appendLine('EmbeDroid abierto: ' + serial);
}

function activate(context) {
  const folder = getWorkspace();
  if (!folder) return;

  openEmbeDroid(folder, 'emulator-5554').catch(error => {
    const message = error instanceof Error ? error.message : String(error);
    output.appendLine('ERROR: ' + message);
    output.show(true);
    vscode.window.showErrorMessage('AI-APPS Android: ' + message);
  });

  context.subscriptions.push(output);
}

function deactivate() {}

module.exports = { activate, deactivate };
