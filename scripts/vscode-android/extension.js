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

  // Una pestaña restaurada puede tener la transmisión cerrada. Recrear solo
  // las vistas EmbeDroid libera el puente anterior sin detener el dispositivo.
  const previousTabs = vscode.window.tabGroups.all.flatMap(group =>
    group.tabs.filter(tab =>
      tab.input instanceof vscode.TabInputWebview &&
      (tab.input.viewType === 'embedroid.embedded' ||
        tab.input.viewType === 'mainThreadWebview-embedroid.embedded')
    )
  );

  if (previousTabs.length > 0) {
    const closed = await vscode.window.tabGroups.close(previousTabs, true);
    if (!closed) {
      throw new Error('No se pudieron cerrar las vistas anteriores de EmbeDroid.');
    }
  }

  await vscode.commands.executeCommand('embedroid.openEmbedded', {
    device: { serial }
  });

  output.appendLine('EmbeDroid abierto: ' + serial);
}

function activate(context) {
  const folder = getWorkspace();
  if (!folder) return;

  context.subscriptions.push(output);

  return openEmbeDroid(folder, 'emulator-5554').catch(error => {
    const message = error instanceof Error ? error.message : String(error);
    output.appendLine('ERROR: ' + message);
    output.show(true);
    vscode.window.showErrorMessage('AI-APPS Android: ' + message);
  });
}

function deactivate() {}

module.exports = { activate, deactivate };
