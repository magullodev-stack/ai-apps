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


function findEmbeDroidExtension() {
  return vscode.extensions.all.find(extension => {
    const manifest = extension.packageJSON || {};
    const haystack = [
      extension.id,
      manifest.name,
      manifest.displayName,
      manifest.description
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();

    return haystack.includes('embedroid');
  });
}

function commandScore(command) {
  const manifestText = [
    command.command,
    command.title,
    command.category
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();

  if (
    /stop|close|disconnect|kill|settings|install|uninstall|delete|remove/.test(
      manifestText
    )
  ) {
    return -100;
  }

  let score = 0;

  if (manifestText.includes('embedroid')) {
    score += 10;
  }

  if (/mirror|screen|device|android/.test(manifestText)) {
    score += 8;
  }

  if (/open|show|start|launch|connect/.test(manifestText)) {
    score += 6;
  }

  return score;
}

async function openEmbeDroid() {
  const extension = findEmbeDroidExtension();

  if (!extension) {
    output.appendLine(
      'EmbeDroid no está instalado; se omite el espejo Android.'
    );
    return;
  }

  await extension.activate();

  const manifest = extension.packageJSON || {};
  const containers = manifest.contributes?.viewsContainers || {};
  const containerCandidates = [
    ...(containers.activitybar || []),
    ...(containers.panel || [])
  ];

  let viewOpened = false;

  for (const container of containerCandidates) {
    if (!container?.id) {
      continue;
    }

    try {
      await vscode.commands.executeCommand(
        'workbench.view.extension.' + container.id
      );
      output.appendLine(
        'EmbeDroid abierto en VS Code: ' + container.id
      );
      viewOpened = true;
      break;
    } catch (_) {
      // Algunos contenedores no exponen el comando estándar; probamos
      // los comandos declarados por la propia extensión.
    }
  }

  const contributedCommands = manifest.contributes?.commands || [];
  const candidates = contributedCommands
    .map(command => ({
      command,
      score: commandScore(command)
    }))
    .filter(entry => entry.score >= 14)
    .sort((a, b) => b.score - a.score);

  for (const candidate of candidates) {
    try {
      await vscode.commands.executeCommand(candidate.command.command);
      output.appendLine(
        'EmbeDroid iniciado: ' + candidate.command.command
      );
      return;
    } catch (error) {
      output.appendLine(
        'EmbeDroid no pudo ejecutar ' +
          candidate.command.command +
          ': ' +
          String(error)
      );
    }
  }

  if (!viewOpened) {
    output.appendLine(
      'EmbeDroid está instalado, pero no expone un comando reconocible para abrirlo automáticamente.'
    );
  }
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

  await openEmbeDroid();
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
