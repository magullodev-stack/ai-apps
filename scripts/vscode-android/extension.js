const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');

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

function execPowerShell(script, cwd) {
  return new Promise((resolve, reject) => {
    childProcess.execFile(
      'powershell.exe',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script],
      { cwd, windowsHide: true, timeout: 300000, maxBuffer: 1024 * 1024 },
      (error, stdout, stderr) => {
        if (stdout) output.appendLine(stdout.trim());
        if (stderr) output.appendLine(stderr.trim());
        if (error) return reject(error);
        resolve(stdout);
      }
    );
  });
}

function startAutoSync(root) {
  const script = path.join(root, 'scripts', 'auto-sync-dev.ps1');
  if (!fs.existsSync(script)) return;

  const child = childProcess.spawn(
    'powershell.exe',
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script],
    { cwd: root, detached: true, windowsHide: true, stdio: 'ignore' }
  );
  child.unref();
}

async function startAndroid(root) {
  const stdout = await execPowerShell(
    path.join(root, 'scripts', 'start-ai-apps-android.ps1'),
    root
  );

  const match = stdout.match(/AI_APPS_ANDROID_SERIAL=([^\r\n]+)/);
  if (!match) {
    throw new Error('Android arrancó sin devolver un dispositivo válido.');
  }

  return match[1].trim();
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

async function launchQuizAI(folder, serial) {
  const root = folder.uri.fsPath;
  const script = path.join(root, 'apps', 'quizai', 'run.ps1');

  const alreadyRunning = vscode.tasks.taskExecutions.some(
    execution =>
      execution.task.definition.type === 'aiAppsQuizAI' ||
      execution.task.name === 'AI-APPS: QuizAI'
  );

  if (alreadyRunning) return;

  const task = new vscode.Task(
    { type: 'aiAppsQuizAI' },
    folder,
    'AI-APPS: QuizAI',
    'AI-APPS',
    new vscode.ProcessExecution(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script,
        '-Device',
        serial
      ],
      { cwd: root }
    )
  );

  task.isBackground = true;
  task.presentationOptions = {
    reveal: vscode.TaskRevealKind.Always,
    panel: vscode.TaskPanelKind.Dedicated,
    focus: false
  };

  await vscode.tasks.executeTask(task);
  output.appendLine('QuizAI lanzado: ' + serial);
}

async function activateEnvironment(folder) {
  const root = folder.uri.fsPath;
  startAutoSync(root);

  output.appendLine('Arrancando Android...');
  const serial = await startAndroid(root);

  await openEmbeDroid(folder, serial);
  await launchQuizAI(folder, serial);
}

function activate(context) {
  const folder = getWorkspace();
  if (!folder) return;

  activateEnvironment(folder).catch(error => {
    const message = error instanceof Error ? error.message : String(error);
    output.appendLine('ERROR: ' + message);
    output.show(true);
    vscode.window.showErrorMessage('AI-APPS Android: ' + message);
  });

  context.subscriptions.push(output);
}

function deactivate() {}

module.exports = { activate, deactivate };
