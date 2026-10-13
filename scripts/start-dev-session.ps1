param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$runtime = Join-Path $repo '.ai-apps'
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
$log = Join-Path $runtime 'dev-session.log'

# Solo estados conocidos: nunca volcar salida de la app, excepciones completas,
# variables de entorno, defines ni el token del servicio en este registro.
function Write-SessionLog([string]$Message) {
    Add-Content -LiteralPath $log -Encoding UTF8 -Value (
        '[{0}] {1}' -f [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'), $Message
    )
}

$stage = 'Sincronizacion'
try {
    # Complete the ignored application's one-time cleanup before starting sync.
    # The marker disappears after cleanup; no retired app name is hardcoded.
    $androidPrepared = $false
    $ignorePath = Join-Path $repo '.gitignore'
    if (Test-Path -LiteralPath $ignorePath) {
        $ignoreText = [IO.File]::ReadAllText($ignorePath, [Text.Encoding]::UTF8)
        $retirement = [regex]::Match($ignoreText,
            '(?m)^# Muondia replaced the previous application directory\.\r?\n# Never re-import generated leftovers from the old local Flutter tree\.\r?\n/apps/([a-z0-9-]+)/\r?$')
        if ($retirement.Success) {
            try {
                $retiredApp = $retirement.Groups[1].Value
                if ($retiredApp -eq 'muondia') { throw 'Invalid retired app.' }
                Write-SessionLog 'Completando limpieza local de migracion.'
                & (Join-Path $PSScriptRoot 'start-ai-apps-android.ps1') *>&1 | Out-Null
                $androidPrepared = $true
                & (Join-Path $PSScriptRoot 'remove-retired-app.ps1') -App $retiredApp -Package ("com.aiapps." + $retiredApp) -SkipEditorInstall *>&1 | Out-Null
                Write-SessionLog 'Limpieza local de migracion verificada.'
            } catch {
                Write-SessionLog ('Limpieza pendiente: {0}.' -f $_.Exception.GetType().Name)
            }
        }
    }

    # Repository-wide background service, independent of any individual app.
    # auto-sync-dev.ps1 already holds an exclusive lock; duplicate launchers exit.
    $autoSyncScript = Join-Path $PSScriptRoot 'auto-sync-dev.ps1'
    if (Test-Path -LiteralPath $autoSyncScript) {
        try {
            $powershellCommand = Get-Command powershell.exe -ErrorAction Stop
            Start-Process -FilePath $powershellCommand.Source `
                -ArgumentList @(
                    '-NoProfile',
                    '-NonInteractive',
                    '-ExecutionPolicy', 'Bypass',
                    '-File', ('"' + $autoSyncScript + '"')
                ) `
                -WorkingDirectory $repo `
                -WindowStyle Hidden | Out-Null
            Write-SessionLog 'Sincronizacion continua de dev solicitada.'
        } catch {
            # Sync is independent: do not prevent Android or Muondia from starting.
            Write-SessionLog ('Sincronizacion no iniciada: {0}.' -f $_.Exception.GetType().Name)
        }
    } else {
        Write-SessionLog 'Sincronizacion no iniciada: script ausente.'
    }

    $stage = 'Android'
    Write-SessionLog 'Preparando Android.'
    if (-not $androidPrepared) {
        & (Join-Path $PSScriptRoot 'start-ai-apps-android.ps1') *>&1 | Out-Null
    }
    Write-SessionLog 'Android preparado: emulator-5554.'
    $stage = 'Muondia'
    Write-SessionLog 'Preparando servicio Dart para VS Code.'
    & (Join-Path $repo 'apps\muondia\run.ps1') -Device emulator-5554 -ServiceOnly *>&1 | Out-Null
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw 'El backend de Muondia no pudo prepararse.'
    }
    Write-SessionLog 'Android y servicio Dart preparados. Flutter se ejecuta desde VS Code.'
} catch {
    Write-SessionLog ('ERROR en {0}: {1}.' -f $stage, $_.Exception.GetType().Name)
    # Categorias fijas para errores operativos, sin incluir datos de la excepcion.
    if ($_.Exception.Message -like '*clave*') {
        Write-SessionLog 'Comprueba la clave DPAPI del usuario con el lanzador de Muondia.'
    } elseif ($_.Exception.Message -like '*Flutter*') {
        Write-SessionLog 'Comprueba Flutter con el lanzador de Muondia en PowerShell.'
    }
    exit 1
}
