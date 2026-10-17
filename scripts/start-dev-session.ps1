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
    # El proceso persistente puede sobrevivir a una tarea detenida. Solo
    # recuperamos procesos verificados como propios; F5 queda intacto.
    $control = Join-Path $PSScriptRoot 'android/task-control.ps1'
    $flutterOwner = (& $control -Action Check -Serial emulator-5554 | Out-String).Trim()
    if ($flutterOwner -eq 'busy') {
        Write-SessionLog 'Flutter previo detectado; verificando propiedad.'
        $recovery = (& $control -Action Recover -Serial emulator-5554 -RepoRoot $repo | Out-String).Trim()
        if ($recovery -eq 'recovered') {
            Write-SessionLog 'Flutter huerfano propio recuperado; reconstruccion solicitada.'
        } elseif ($recovery -eq 'free') {
            Write-SessionLog 'Flutter previo termino antes de recuperarlo.'
        } else {
            Write-SessionLog 'ERROR: Flutter ajeno o no recuperable; no se toca F5.'
            throw 'Ya existe una sesion Flutter ajena o no recuperable en emulator-5554.'
        }
    }
    # Revalidar siempre: nunca construir un segundo Flutter en el dispositivo.
    $flutterOwner = (& $control -Action Check -Serial emulator-5554 | Out-String).Trim()
    if ($flutterOwner -ne 'free') {
        Write-SessionLog 'ERROR: emulator-5554 continua ocupado tras la comprobacion.'
        throw 'Ya existe una sesion Flutter en emulator-5554.'
    }
    Write-SessionLog 'Iniciando servicio Dart y sesion Flutter.'
    & (Join-Path $repo 'apps\muondia\run.ps1') -Device emulator-5554 *>&1 |
        ForEach-Object {
            $line = $_.ToString().Trim()
            if ($line -eq 'Hot reload automatico completado.' -or
                $line -eq 'Hot restart completado.') {
                Write-SessionLog $line
            } elseif ($line -like 'Hot reload automatico activo:*') {
                Write-SessionLog 'Muondia preparado; hot reload automatico activo.'
            } elseif ($line -like 'Cambio detectado:*') {
                Write-SessionLog 'Cambio de codigo/asset detectado.'
            } elseif ($line -like 'Cambio nativo/dependencias detectado:*' -or
                      $line -like 'Cambio nativo detectado; recompilando*') {
                Write-SessionLog 'Cambio nativo detectado; reconstruccion solicitada.'
            } elseif ($line -like 'FIREBASE_CONFIG_OK:*') {
                Write-SessionLog 'Configuracion Firebase Android verificada.'
            } elseif ($line -like 'Running Gradle task*') {
                Write-SessionLog 'Compilacion Gradle iniciada.'
            } elseif ($line -match '^Hot (reload|restart) fallo:') {
                # Retener el código de fallo sin persistir detalles sensibles.
                if ($line -match '^Hot (reload|restart) fallo: (codigo_-?[0-9]+|protocolo(?:_-?[0-9]+)?|respuesta_invalida|resultado_no_valido|timeout)$') {
                    Write-SessionLog ("ERROR Flutter: Hot {0} fallido ({1})." -f $Matches[1], $Matches[2])
                } else {
                    Write-SessionLog 'ERROR Flutter: actualización fallida (tipo desconocido).'
                }
            } elseif ($line -eq 'Recuperacion Flutter: Hot restart automatico solicitado.') {
                Write-SessionLog 'Recuperacion automatica: Hot Restart tras fallo de Hot Reload.'
            } elseif ($line -eq 'Recuperacion Flutter: canal bloqueado; relanzamiento controlado.') {
                Write-SessionLog 'Recuperacion automatica: canal Flutter bloqueado; relanzamiento del proceso propio.'
            }
        }
    Write-SessionLog 'Sesion Flutter terminada.'
} catch {
    Write-SessionLog ('ERROR en {0}: {1}.' -f $stage, $_.Exception.GetType().Name)
    # Categorias fijas para errores operativos, sin incluir datos de la excepcion.
    if ($_.Exception.Message -like '*FIREBASE_CONFIG_MISSING*') {
        Write-SessionLog 'ERROR: falta google-services.json en Muondia.'
    } elseif ($_.Exception.Message -like '*FIREBASE_CONFIG_INVALID*') {
        Write-SessionLog 'ERROR: google-services.json invalido o pertenece a otra app.'
    } elseif ($_.Exception.Message -like '*clave*') {
        Write-SessionLog 'Comprueba la clave DPAPI del usuario con el lanzador de Muondia.'
    } elseif ($_.Exception.Message -like '*Flutter*') {
        Write-SessionLog 'Comprueba Flutter con el lanzador de Muondia en PowerShell.'
    }
    exit 1
}
