const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');

const EMBEDROID_ID = 'utpalbarman.embedroid';

const output = vscode.window.createOutputChannel(
  'AI-APPS Android'
);

// ------------------------------------------------------------
// IDENTIFICAR EL PROYECTO
// ------------------------------------------------------------

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

// ------------------------------------------------------------
// COMPROBAR SI EL VISOR YA ESTÁ ABIERTO
// ------------------------------------------------------------

function isEmbeddedViewOpen() {
  return vscode.window.tabGroups.all.some(group =>
    group.tabs.some(tab =>
      tab.input instanceof vscode.TabInputWebview &&
      tab.input.viewType === 'embedroid.embedded'
    )
  );
}

// ------------------------------------------------------------
// EJECUTAR EL ARRANQUE COMPARTIDO
// ------------------------------------------------------------

function startAndroid(root) {
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
        timeout: 300000,
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
          /AI_APPS_ANDROID_SERIAL=(emulator-\d+)/
        );

        if (!match) {
          reject(
            new Error(
              'El procedimiento no devolvió un emulador preparado.'
            )
          );
          return;
        }

        resolve(match[1]);
      }
    );
  });
}

// ------------------------------------------------------------
// CONFIGURAR EL VISOR INTEGRADO
// ------------------------------------------------------------

async function configureEmbeddedView(folder) {
  const config = vscode.workspace.getConfiguration(
    'embedroid',
    folder.uri
  );

  // Abrir Android en el grupo de editores actual.
  // No crear una columna lateral para el teléfono.

  if (config.get('openIn') !== 'active') {
    await config.update(
      'openIn',
      'active',
      vscode.ConfigurationTarget.Workspace
    );
  }

  // El emulador debe funcionar sin ventana externa.

  if (config.get('headless') !== true) {
    await config.update(
      'headless',
      true,
      vscode.ConfigurationTarget.Workspace
    );
  }
}

// ------------------------------------------------------------
// ARRANQUE DEL ENTORNO
// ------------------------------------------------------------

async function launchSelectedGame(folder) {
  const root = folder.uri.fsPath;
  const selectionFile = path.join(
    root,
    '.ai-apps',
    'active-game.txt'
  );

  if (!fs.existsSync(selectionFile)) {
    output.appendLine('No hay juego activo seleccionado.');
    return;
  }

  const game = fs.readFileSync(selectionFile, 'utf8')
    .trim()
    .toLowerCase();

  // "none" permite abrir AI-APPS sin ejecutar ningún juego.

  if (!game || game === 'none') {
    output.appendLine('AI-APPS abierto sin juego activo.');
    return;
  }

  // El selector contiene nombres de carpetas, nunca rutas
  // ni comandos introducidos por el usuario.

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
        script
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
    'Ejecutando juego activo: ' + game
  );

  await vscode.tasks.executeTask(task);
}

async function startEnvironment(folder) {
  output.appendLine('Preparando Android para AI-APPS...');

  const embedroid = vscode.extensions.getExtension(
    EMBEDROID_ID
  );

  if (!embedroid) {
    throw new Error(
      'EmbeDroid no está instalado en VS Code.'
    );
  }

  await configureEmbeddedView(folder);

  // Preparar Android independientemente del juego.
  // Si ya está funcionando, el script lo reutiliza.

  const serial = await startAndroid(
    folder.uri.fsPath
  );

  output.appendLine(
    'Android preparado: ' + serial
  );

  // Activar EmbeDroid antes de utilizar su comando.

  await embedroid.activate();

  // Si VS Code ha restaurado la pestaña integrada,
  // no abrir una segunda copia.

  if (isEmbeddedViewOpen()) {
    output.appendLine(
      'El visor integrado ya está abierto.'
    );
    await launchSelectedGame(folder);
    return;
  }

  // Abrir la pestaña del dispositivo preparado.

  await vscode.commands.executeCommand(
    'embedroid.openEmbedded',
    {
      device: {
        serial: serial
      }
    }
  );

  output.appendLine(
    'Visor integrado solicitado a EmbeDroid.'
  );

  await launchSelectedGame(folder);
}

// ------------------------------------------------------------
// ACTIVACIÓN DE LA EXTENSIÓN
// ------------------------------------------------------------

function activate(context) {
  const folder = getAiAppsWorkspace();

  // La integración solamente se ejecuta en AI-APPS.
  // No debe iniciar Android al abrir otros proyectos.

  if (!folder) {
    return;
  }

  startEnvironment(folder).catch(error => {
    const message = error instanceof Error
      ? error.message
      : String(error);

    output.appendLine('ERROR: ' + message);

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