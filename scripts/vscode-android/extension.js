const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');

const output = vscode.window.createOutputChannel(
  'AI-APPS Android'
);

function getAiAppsWorkspace() {
  const folders = vscode.workspace.workspaceFolders || [];

  return folders.find(folder => {
    const root = folder.uri.fsPath;

    return (
      path.basename(root).toLowerCase() === 'ai-apps' &&
      fs.existsSync(path.join(root, 'AGENTS.md')) &&
      fs.existsSync(
        path.join(root, 'scripts', 'start-android.ps1')
      )
    );
  });
}

function preparePhysicalAndroid(root) {
  return new Promise((resolve, reject) => {
    const script = path.join(
      root,
      'scripts',
      'start-android.ps1'
    );

    childProcess.execFile(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script
      ],
      {
        cwd: root,
        windowsHide: true,
        timeout: 60000,
        maxBuffer: 1024 * 1024
      },
      (error, stdout, stderr) => {
        if (stdout) {
          output.appendLine(stdout);
        }

        if (stderr) {
          output.appendLine(stderr);
        }

        if (error) {
          reject(error);
          return;
        }

        const match = stdout.match(
          /AI_APPS_ANDROID_SERIAL=([^\r\n]+)/
        );

        if (!match) {
          reject(
            new Error(
              'El procedimiento no devolvió un dispositivo Android físico preparado.'
            )
          );
          return;
        }

        resolve(match[1].trim());
      }
    );
  });
}

async function launchSelectedGame(folder, serial) {
  const root = folder.uri.fsPath;
  const selectionFile = path.join(
    root,
    '.ai-apps',
    'active-game.txt'
  );

  let game;

  if (!fs.existsSync(selectionFile)) {
    const quizaiLauncher = path.join(
      root,
      'apps',
      'quizai',
      'run.ps1'
    );

    if (!fs.existsSync(quizaiLauncher)) {
      output.appendLine('No hay juego activo seleccionado.');
      return;
    }

    game = 'quizai';
    output.appendLine(
      'Sin selector local; se usa QuizAI como aplicación de desarrollo.'
    );
  } else {
    game = fs.readFileSync(selectionFile, 'utf8')
      .trim()
      .toLowerCase();
  }

  if (!game || game === 'none') {
    output.appendLine('AI-APPS abierto sin juego activo.');
    return;
  }

  if (!/^[a-z][a-z0-9_-]*$/.test(game)) {
    throw new Error(
      'Nombre de juego no válido en .ai-apps/active-game.txt'
    );
  }

  const script = path.join(
    root,
    'apps',
    game,
    'run.ps1'
  );

  if (!fs.existsSync(script)) {
    throw new Error(
      'El juego "' + game + '" no tiene lanzador: ' + script
    );
  }

  const alreadyRunning = vscode.tasks.taskExecutions.some(
    execution =>
      (
        execution.task.definition.type === 'aiAppsGame' &&
        execution.task.definition.game === game
      ) ||
      (
        game === 'quizai' &&
        execution.task.name ===
          'AI-APPS: ejecutar QuizAI con IA'
      )
  );

  if (alreadyRunning) {
    output.appendLine(
      'Ya existe una tarea activa para ' + game + '.'
    );
    return;
  }

  const task = new vscode.Task(
    {
      type: 'aiAppsGame',
      game: game
    },
    folder,
    'AI-APPS: ejecutar ' + game,
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
      {
        cwd: root
      }
    )
  );

  task.isBackground = true;

  task.presentationOptions = {
    reveal: vscode.TaskRevealKind.Always,
    panel: vscode.TaskPanelKind.Dedicated,
    focus: false
  };

  output.appendLine(
    'Ejecutando ' + game + ' en ' + serial
  );

  await vscode.tasks.executeTask(task);
}

async function startEnvironment(folder) {
  output.appendLine(
    'Preparando dispositivo Android físico para AI-APPS...'
  );

  const serial = await preparePhysicalAndroid(
    folder.uri.fsPath
  );

  output.appendLine(
    'Android físico preparado: ' + serial
  );

  await launchSelectedGame(folder, serial);
}

function activate(context) {
  const folder = getAiAppsWorkspace();

  if (!folder) {
    return;
  }

  startEnvironment(folder).catch(error => {
    const message = error instanceof Error
      ? error.message
      : String(error);

    output.appendLine('ERROR: ' + message);
    output.show(true);

    vscode.window.showErrorMessage(
      'AI-APPS Android: ' + message
    );
  });

  context.subscriptions.push(output);
}

function deactivate() {}

module.exports = {
  activate,
  deactivate
};
