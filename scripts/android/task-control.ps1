param(
    [ValidateSet('Check', 'Stop')][string]$Action,
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
    throw 'Stop controls only AI-APPS Development.'
}

# Identificar exclusivamente la sesion persistente de ESTE repositorio.
# Flutter lanza un segundo dart.exe mediante flutter.bat. Matar solo el
# runner no siempre termina ese hijo, que mantiene ocupado emulator-5554.
$repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
$runnerPath = (Join-Path $repo 'scripts\flutter-dev-runner.dart').ToLowerInvariant()
$nativeDefinesPath = (Join-Path $repo '.ai-apps\onboardingQuiz-defines.json').ToLowerInvariant()

function Test-IsPersistentMuondiaProcess($Process) {
    if (-not $Process.CommandLine) { return $false }
    $command = $Process.CommandLine.Replace('/', '\').ToLowerInvariant()
    if ($command.Contains($runnerPath)) { return $true }

    # Solo el proceso Flutter de la sesion persistente usa estos defines.
    # F5 usa muondia-flutter-defines.json y no se mata desde aqui.
    if ($command.Contains($nativeDefinesPath) -and
        ($command.Contains('flutter_tools.snapshot') -or
         $command.Contains('flutter_tools') -or
         $command.Contains('flutter run'))) {
        return $true
    }
    return $false
}

Stop-ScheduledTask -TaskName 'AI-APPS Development'

# Releer despues de detener la tarea porque su proceso padre puede finalizar
# antes de que se cierre el flutter run hijo.
for ($attempt = 0; $attempt -lt 12; $attempt++) {
    $owned = @(Get-DeviceDartProcesses | Where-Object {
        Test-IsPersistentMuondiaProcess $_
    })

    foreach ($process in $owned) {
        $current = Get-CimInstance Win32_Process -Filter "ProcessId=$($process.ProcessId)"
        if ($current -and
            $current.CreationDate -eq $process.CreationDate -and
            $current.CommandLine -eq $process.CommandLine) {
            # El arbol pertenece al runner/Flutter persistente de Muondia.
            # Puede desaparecer mientras se libera otro proceso del arbol.
            & taskkill.exe /PID $process.ProcessId /T /F 2>$null | Out-Null
        }
    }

    $remaining = @(Get-DeviceDartProcesses)
    if ($remaining.Count -eq 0) { break }
    Start-Sleep -Milliseconds 500
}

$remaining = @(Get-DeviceDartProcesses)
if ($remaining.Count -gt 0) {
    # No matar Dart de otros depuradores/aplicaciones sin verificar propiedad.
    $pids = (@($remaining | ForEach-Object { $_.ProcessId }) -join ', ')
    throw "emulator-5554 sigue ocupado por Dart (PID: $pids). No se han detenido procesos ajenos a Muondia."
}

$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
& (Join-Path $sdk 'platform-tools\adb.exe') -s emulator-5554 shell am force-stop com.aiapps.muondia | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not stop Muondia application.' }
