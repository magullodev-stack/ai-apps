# Git se sincroniza al iniciar Windows; no arranca Android, Flutter ni Dart.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$old = Get-ScheduledTask -TaskName 'AI-APPS Development' -ErrorAction SilentlyContinue
if ($old) {
    if ($old.State -eq 'Running') {
        Stop-ScheduledTask -TaskName 'AI-APPS Development'
    }
    Unregister-ScheduledTask -TaskName 'AI-APPS Development' -Confirm:$false
}
$action = New-ScheduledTaskAction -Execute (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') `
    -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $PSScriptRoot 'auto-sync-dev.ps1')) `
    -WorkingDirectory $repo
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -DontStopOnIdleEnd `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName 'AI-APPS Git Sync' -Action $action `
    -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName 'AI-APPS Git Sync'
Write-Host 'Git sincroniza dev independientemente de VS Code; tarea antigua retirada.'
