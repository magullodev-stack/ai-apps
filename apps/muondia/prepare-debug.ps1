# F5 toma temporalmente el control de Muondia y lo devuelve al terminar.
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$taskName = 'AI-APPS Development'
$marker = Join-Path $repo '.ai-apps\muondia-f5-takeover.txt'
$control = Join-Path $repo 'scripts\android\task-control.ps1'
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
$takenOver = $false

try {
    # Un marcador antiguo no debe reiniciar una sesion que el usuario ya detuvo.
    if ($task -and $task.State -eq 'Running') {
        & $control -Action Stop -Serial emulator-5554 -RepoRoot $repo
        if ($LASTEXITCODE -ne 0) {
            throw 'No se pudo liberar la sesion persistente para F5.'
        }
        $takenOver = $true
        New-Item -ItemType Directory -Force -Path (Split-Path $marker -Parent) | Out-Null
        Set-Content -LiteralPath $marker -Value 'restore' -Encoding ASCII
    } else {
        Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue
    }

    $free = $false
    for ($i = 0; $i -lt 30; $i++) {
        $owner = (& $control -Action Check -Serial emulator-5554 | Out-String).Trim()
        if ($owner -eq 'free') {
            $free = $true
            break
        }
        Start-Sleep -Milliseconds 500
    }
    if (-not $free) {
        throw 'No se ha liberado emulator-5554; no se iniciara otro Flutter.'
    }

    & (Join-Path $repo 'scripts\start-ai-apps-android.ps1') *>&1 | Out-Host
    & (Join-Path $PSScriptRoot 'run.ps1') -Device emulator-5554 -ServiceOnly *>&1 | Out-Host
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw 'No se pudo preparar Muondia para depurar.'
    }
    Write-Host 'F5 preparado: VS Code controla Flutter hasta detener la depuracion.'
} catch {
    if ($takenOver) {
        try {
            Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
            Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning 'No se pudo restaurar la sesion persistente tras el error de F5.'
        }
    }
    throw
}
