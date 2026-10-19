# PreLaunchTask de VS Code. Flutter pertenece exclusivamente a la extension Dart.
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
} else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'
if (-not (Test-Path -LiteralPath $adb) -or -not (Test-Path -LiteralPath $emulator)) {
    throw 'Android SDK no disponible.'
}
$avdName = 'AI_APPS_Dev'
$serial = 'emulator-5554'
$online = @(& $adb devices) -match '^emulator-5554\s+device\s*$'
if (-not $online) {
    # Si Android ya esta arrancando, esperarlo: nunca lanzar un segundo QEMU.
    $runningEmulator = @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -in @('emulator.exe', 'qemu-system-x86_64.exe', 'qemu-system-x86_64-headless.exe',
            'qemu-system-aarch64.exe', 'qemu-system-aarch64-headless.exe') -and
        ($_.CommandLine -match '(?i)(?:^|\s)-port\s+5554(?:\s|$)' -or
         $_.CommandLine -match '(?i)(?:^|\s)-avd\s+"?AI_APPS_Dev"?(?:\s|$)')
    })
    if (-not $runningEmulator) {
        $available = @(& $emulator -list-avds)
        if ($avdName -notin $available) { throw 'Falta el AVD AI_APPS_Dev.' }
        Write-Host 'Arrancando Android para Muondia...'
        Start-Process -FilePath $emulator -ArgumentList @(
            '-avd', $avdName, '-port', '5554', '-no-window',
            '-no-boot-anim', '-no-snapshot', '-feature', '-Vulkan'
        ) -WindowStyle Hidden | Out-Null
    } else { Write-Host 'Esperando al Android existente...' }
}
$ready = $false
for ($i = 0; $i -lt 180; $i++) {
    # Un dispositivo que aun no figura en ADB es normal durante el arranque.
    # No convertir stderr nativo en un error terminante de PowerShell 5.1.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $connected = @(& $adb devices 2>$null) -match '^emulator-5554\s+device\s*
if (-not $ready) { throw 'Android no ha terminado de arrancar. Revisa la salida del emulador.' }
& (Join-Path $PSScriptRoot 'run.ps1') -Device $serial -ServiceOnly
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw 'No se pudo preparar el servicio de IA.' }
Write-Host 'Muondia preparada. VS Code iniciara Flutter con Dart-Code.'

        if ($connected) {
            $booted = (& $adb -s $serial shell getprop sys.boot_completed 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and $booted -eq '1') {
                $ready = $true
                break
            }
        }
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    Start-Sleep -Seconds 1
}
if (-not $ready) { throw 'Android no ha terminado de arrancar. Revisa la salida del emulador.' }
& (Join-Path $PSScriptRoot 'run.ps1') -Device $serial -ServiceOnly
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw 'No se pudo preparar el servicio de IA.' }
Write-Host 'Muondia preparada. VS Code iniciara Flutter con Dart-Code.'
