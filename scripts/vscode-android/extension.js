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