# Android en VS Code

Muondia utiliza la extension oficial Flutter/Dart de VS Code. Al abrir el repositorio,
AI-APPS Android solicita **una sola** depuracion `Muondia` de `.vscode/launch.json`.
El `preLaunchTask` de `apps/muondia/prepare-debug.ps1` inicia el AVD
`AI_APPS_Dev` si hace falta, espera a `emulator-5554` y prepara el servicio
Dart y los defines privados mediante `apps/muondia/run.ps1 -ServiceOnly`.

El depurador oficial ejecuta Flutter y aplica Hot Reload/Restart. El visor
EmbeDroid solo muestra Android y reconecta video cuando hay una sesion
Flutter activa. El Explorador envia intents de desarrollo a esa misma APK;
no abre una segunda instancia Flutter.

El postDebugTask detiene el backend Dart y el AVD reservado cuando
termina la depuracion. Al cerrar VS Code termina la sesion Dart-Code. No existe el antiguo supervisor
`AI-APPS Development`, runner Dart personalizado ni workers Flutter.

## Git independiente

`scripts/install-git-sync.ps1` instala la tarea **AI-APPS Git Sync** al iniciar
sesion en Windows y retira la tarea antigua. Solo ejecuta
`scripts/auto-sync-dev.ps1`; no prepara Android, Flutter ni la IA. Instalacion
unica desde PowerShell: `powershell -ExecutionPolicy Bypass -File scripts/install-git-sync.ps1`.
Tras instalar, reinicia Windows para limpiar los procesos antiguos.

Los registros históricos de otras aplicaciones cuyo proyecto ya no existe
se omiten **solo en memoria**, sin modificar `.ai-apps/android/sessions.json`.
Nunca deben bloquear el inicio de Muondia.

## Otras aplicaciones

`scripts/android-session.ps1` conserva List/Register/Unregister para dispositivos
independientes. Las aplicaciones Flutter registradas se inician y detienen
desde **AI-APPS Android** mediante el depurador Dart-Code, con su propio
AVD ya conectado. Las aplicaciones externas solo se visualizan.

## Pruebas

`node scripts/android/test.cjs` y
`node scripts/vscode-android/test.cjs`.
La comprobacion final exige abrir VS Code en Windows, ver Muondia,
abrir Test de bienvenida, guardar un cambio Dart, recibir otro desde Git
y reiniciar Windows; las pruebas de Node no sustituyen ese recorrido.
