# Prueba técnica de Flutter

`apps/quiz10/` se conserva temporalmente para comprobar la compilación, la ejecución móvil y Hot Reload desde Windows. La aplicación actual es el contador de ejemplo de Flutter. Esta tarea no incorpora funcionalidades de Quiz10.

## Entorno local

Utiliza PowerShell de Windows y las instalaciones nativas existentes:

- Flutter: `%USERPROFILE%\development\flutter`; incluye Dart.
- Android SDK: `%LOCALAPPDATA%\Android\Sdk`; incluye ADB y el emulador.
- JDK: la compilación Android auditada utiliza el incluido en Android Studio, JBR 25, en `C:\Program Files\Android\Android Studio\jbr`. El `java` del `PATH` puede corresponder a otra instalación; utiliza Flutter para compilar esta aplicación.
- VS Code: extensiones Dart (`Dart-Code.dart-code`) y Flutter (`Dart-Code.flutter`).

Prepara las rutas y comprueba la instalación:

```powershell
$flutter = Join-Path $env:USERPROFILE 'development\flutter\bin\flutter.bat'
$androidSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb = Join-Path $androidSdk 'platform-tools\adb.exe'
$emulator = Join-Path $androidSdk 'emulator\emulator.exe'

& $flutter --version
& $flutter doctor -v
& $flutter emulators
& $emulator -list-avds
& $adb devices -l
code --list-extensions
```

El proyecto Android tiene su propio wrapper Gradle en `android/`. Ejecuta los comandos Flutter desde esta aplicación; no necesita una compilación Gradle en la raíz del repositorio.

## Verificación y compilación

En la misma sesión de PowerShell:

```powershell
Set-Location 'C:\Users\Miquelet\repos\ai-apps\apps\quiz10'
& $flutter pub get
& $flutter analyze
& $flutter test
& $flutter build apk --debug
```

Comprueba el resultado de cada comando antes de continuar. El APK de depuración se genera en `build\app\outputs\flutter-apk\app-debug.apk`.

## Ejecución manual y Hot Reload

Desde la raíz del repositorio puedes iniciar la prueba Android manualmente:

```powershell
Set-Location 'C:\Users\Miquelet\repos\ai-apps'
.\scripts\run-android.ps1
```

El script utiliza `flutter.bat` del `PATH` o la instalación indicada arriba. Para el Android SDK consulta `ANDROID_HOME`, `ANDROID_SDK_ROOT` y, finalmente, la ruta local indicada. Reutiliza un emulador conectado o inicia el primer AVD disponible; después prepara las dependencias y ejecuta la aplicación. Si hay varias aplicaciones Flutter, permite elegir una.

También puedes iniciar el emulador desde Android Studio, consultar su identificador y ejecutar Flutter directamente:

```powershell
Set-Location 'C:\Users\Miquelet\repos\ai-apps\apps\quiz10'
& $flutter devices
& $flutter run -d '<identificador-del-dispositivo>'
```

Sustituye el identificador por el mostrado por `flutter devices`. La sesión de `flutter run` permanece abierta para el desarrollo.

Para comprobar Hot Reload, incrementa el contador, cambia temporalmente un texto visible de `lib/main.dart`, guarda el archivo y pulsa `r` en la terminal de Flutter. El texto debe actualizarse conservando el valor del contador. Restaura después ese cambio de prueba y vuelve a pulsar `r`. La tecla `R` reinicia la aplicación; `q` finaliza la sesión.

Coordina cualquier ejecución que pueda afectar a una sesión activa.
