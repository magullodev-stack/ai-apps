param(
    [ValidateSet('Check', 'Stop', 'Recover')][string]$Action,
    [string]$Serial = 'emulator-5554',
    [string]$RepoRoot
)
$ErrorActionPreference = 'Stop'
$escapedSerial = [regex]::Escape($Serial)

function Get-DeviceDartProcesses {
    @(
        Get-CimInstance Win32_Process | Where-Object {
            $_.Name -in @('dart.exe', 'dartvm.exe') -and
            ($_.CommandLine -match ('--device\s+"?' + $escapedSerial + '(?:"|\s|$)') -or
             $_.CommandLine -match ('(?:--device-id|-d)\s+"?' + $escapedSerial + '(?:"|\s|$)'))
        }
    )
}

if ($Action -eq 'Check') {
    if (@(Get-DeviceDartProcesses).Count -gt 0) {
        Write-Output 'busy'
    } else {
        Write-Output 'free'
    }
    return
}

if ($Serial -ne 'emulator-5554' -or -not $RepoRoot) {
    throw 'Only AI-APPS Development on emulator-5554 can be stopped or recovered.'
}

$repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
. (Join-Path $PSScriptRoot 'flutter-ownership.ps1')

if ($Action -eq 'Stop') {
    # Parada explicita desde el editor/F5. Nunca desde la propia tarea.
    Stop-ScheduledTask -TaskName 'AI-APPS Development'
} else {
    # La recuperacion se invoca DURANTE el arranque; no debe detener al padre.
    $ownership = Get-MuondiaFlutterOwnership -Processes @(Get-DeviceDartProcesses) -RepoRoot $repo
    if ($ownership -eq 'free') {
        Write-Output 'free'
        return
    }
    if ($ownership -ne 'owned') {
        Write-Output 'foreign'
        return
    }
}

# Comprobar otra vez la propiedad antes de cada terminacion. Nunca terminar
# F5 u otro Flutter en el mismo dispositivo, ni procesos cuyo PID se reutilizo.
for ($attempt = 0; $attempt -lt 12; $attempt++) {
    $snapshot = @(Get-DeviceDartProcesses)
    if ($snapshot.Count -eq 0) { break }

    $ownership = Get-MuondiaFlutterOwnership -Processes $snapshot -RepoRoot $repo
    if ($Action -eq 'Recover' -and $ownership -ne 'owned') {
        Write-Output 'foreign'
        return
    }

    $owned = @($snapshot | Where-Object {
        Test-IsPersistentMuondiaProcess -Process $_ -RepoRoot $repo
    })

    foreach ($process in $owned) {
        $current = Get-CimInstance Win32_Process -Filter "ProcessId=$($process.ProcessId)"
        if ($current -and
            $current.CreationDate -eq $process.CreationDate -and
            $current.CommandLine -eq $process.CommandLine -and
            (Test-IsPersistentMuondiaProcess -Process $current -RepoRoot $repo)) {
            & taskkill.exe /PID $process.ProcessId /T /F 2>$null | Out-Null
        }
    }
    Start-Sleep -Milliseconds 500
}

$remaining = @(Get-DeviceDartProcesses)
if ($remaining.Count -gt 0) {
    if ($Action -eq 'Recover') {
        # No arrancar un segundo Flutter, incluso si el proceso es propio.
        Write-Output 'foreign'
        return
    }
    $pids = (@($remaining | ForEach-Object { $_.ProcessId }) -join ', ')
    throw "emulator-5554 sigue ocupado por Dart (PID: $pids). No se han detenido procesos ajenos a Muondia."
}

$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
& (Join-Path $sdk 'platform-tools\adb.exe') -s emulator-5554 shell am force-stop com.aiapps.muondia | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not stop Muondia application.' }

if ($Action -eq 'Recover') { Write-Output 'recovered' }
