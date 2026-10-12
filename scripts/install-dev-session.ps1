param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction -Execute (
    Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
) -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f (
    Join-Path $PSScriptRoot 'start-dev-session.ps1'
)) -WorkingDirectory $repo
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew `
    -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -DontStopOnIdleEnd `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName 'AI-APPS Development' -Action $action `
    -Trigger $trigger -Principal $principal -Settings $settings `
    -Description 'Sincronizacion continua de dev, Android y QuizAI con hot reload.' `
    -Force | Out-Null
Write-Host 'Tarea AI-APPS Development instalada para el usuario actual.'
Write-Host "Iniciar ahora: Start-ScheduledTask -TaskName 'AI-APPS Development'"
