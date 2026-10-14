# Depuracion Flutter opcional. Nunca detener el desarrollo persistente.
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

$task = Get-ScheduledTask -TaskName 'AI-APPS Development' -ErrorAction SilentlyContinue
if ($task -and $task.State -eq 'Running') {
    throw 'Muondia ya pertenece a AI-APPS Development. Deten la tarea de forma explicita antes de utilizar F5.'
}

$control = Join-Path $repo 'scripts\android\task-control.ps1'
$owner = (& $control -Action Check -Serial emulator-5554 | Out-String).Trim()
if ($owner -ne 'free') {
    throw 'Hay otra sesion Flutter en emulator-5554. No se iniciara un segundo proceso.'
}

& (Join-Path $repo 'scripts\start-ai-apps-android.ps1') *>&1 | Out-Host
& (Join-Path $PSScriptRoot 'run.ps1') -Device emulator-5554 -ServiceOnly *>&1 | Out-Host
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw 'No se pudo preparar el backend de Muondia para F5.'
}
