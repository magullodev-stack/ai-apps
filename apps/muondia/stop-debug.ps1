# postDebugTask de Dart-Code: cerrar lo que se preparo para esta sesion.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'run.ps1') -StopService
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
} else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$adb = Join-Path $sdk 'platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adb)) { return }
# El dispositivo 5554 esta reservado para Muondia: no cerrar otros AVD.
$avd = (& $adb -s emulator-5554 emu avd name 2>$null | Out-String)
if ($LASTEXITCODE -eq 0 -and $avd -match '(?m)^AI_APPS_Dev\r?$') {
    & $adb -s emulator-5554 emu kill | Out-Null
}
