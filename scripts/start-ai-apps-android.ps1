param(
    [ValidatePattern('^[A-Za-z0-9_-]+$')][string]$AvdName = 'AI_APPS_Dev',
    [ValidatePattern('^emulator-[0-9]+$')][string]$Serial = 'emulator-5554'
)

$ErrorActionPreference = 'Stop'

$port = [int]($Serial -replace '^emulator-', '')
if ($port -lt 5554 -or $port -gt 5682 -or $port % 2) { throw 'Puerto de emulador no valido.' }
if (($Serial -eq 'emulator-5554') -ne ($AvdName -eq 'AI_APPS_Dev')) {
    throw 'AI_APPS_Dev y emulator-5554 estan reservados para la sesion persistente.'
}
$SystemImage = 'system-images;android-36;google_apis_playstore;x86_64'

$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }

$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'
$avdmanager = Join-Path $sdk 'cmdline-tools\latest\bin\avdmanager.bat'

foreach ($tool in @($adb, $emulator, $avdmanager)) {
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "Falta una herramienta Android necesaria: $tool"
    }
}

function Test-EmulatorReady {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = & $adb devices 2>$null
        if ($LASTEXITCODE -ne 0) { return $false }

        $deviceLine = $lines | Where-Object {
            $_ -match "^$([regex]::Escape($Serial))\s+device\s*$"
        } | Select-Object -First 1

        if (-not $deviceLine) { return $false }

        $actualAvd = (& $adb -s $Serial shell getprop ro.boot.qemu.avd_name 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $actualAvd -ne $AvdName) {
            throw 'El dispositivo pertenece a otro AVD.'
        }

        $boot = (& $adb -s $Serial shell getprop sys.boot_completed 2>$null | Out-String).Trim()
        return ($LASTEXITCODE -eq 0 -and $boot -eq '1')
    }
    catch {
        return $false
    }
    finally {
        $ErrorActionPreference = $previous
    }
}

function Get-EmulatorProcesses {
    @(
        Get-CimInstance Win32_Process | Where-Object {
            $_.Name -in @('emulator.exe', 'qemu-system-x86_64.exe',
                'qemu-system-x86_64-headless.exe', 'qemu-system-aarch64.exe',
                'qemu-system-aarch64-headless.exe')
        }
    )
}

# La ausencia en ADB no demuestra que QEMU haya terminado.
function Get-ManagedAvdProcesses {
    $avdArg = '(?i)(^|\s)-avd(?:\s+|=)"?' + [regex]::Escape($AvdName) + '"?(?=\s|$)'
    $portArg = '(?i)(^|\s)-port(?:\s+|=)"?' + [regex]::Escape([string]$port) + '"?(?=\s|$)'
    @(
        Get-EmulatorProcesses | Where-Object {
            $_.CommandLine -match $avdArg -and
            $_.CommandLine -match $portArg
        }
    )
}

function Get-EmulatorPortProcesses {
    $portArg = '(?i)(^|\s)-port(?:\s+|=)"?' +
        [regex]::Escape([string]$port) + '"?(?=\s|$)'
    @(Get-EmulatorProcesses | Where-Object { $_.CommandLine -match $portArg })
}

function Test-ManagedQemuPresent {
    $processes = @(Get-EmulatorProcesses)
    $owned = @(Get-ManagedAvdProcesses)
    if (@($owned | Where-Object { $_.Name -ne 'emulator.exe' }).Count -gt 0) {
        return $true
    }
    # Un hijo puede no repetir -avd/-port. Su wrapper no es huerfano.
    $wrapperPids = @($owned | Where-Object { $_.Name -eq 'emulator.exe' } |
        ForEach-Object { $_.ProcessId })
    return @($processes | Where-Object {
        $_.Name -ne 'emulator.exe' -and $_.ParentProcessId -in $wrapperPids
    }).Count -gt 0
}

function Assert-AvdAvailableForStartup([string]$RepoRoot) {
    $f5Marker = Join-Path $RepoRoot '.ai-apps/muondia-f5-takeover.txt'
    if (Test-Path -LiteralPath $f5Marker) {
        throw 'F5 tiene cedido emulator-5554; no se modifica su AVD.'
    }
    $control = Join-Path $RepoRoot 'scripts/android/task-control.ps1'
    if (Test-Path -LiteralPath $control) {
        $flutterState = (& $control -Action Check -Serial $Serial | Out-String).Trim()
        if ($flutterState -ne 'free') {
            throw 'Flutter ocupa emulator-5554; no se modifica el AVD.'
        }
    }
}

function Get-SerialState {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = & $adb devices 2>$null
        if ($LASTEXITCODE -ne 0) { return 'unknown' }
        foreach ($line in @($lines)) {
            if ($line -match ('^' + [regex]::Escape($Serial) + '\s+(\S+)')) {
                return $Matches[1]
            }
        }
        return 'missing'
    } catch {
        return 'unknown'
    } finally {
        $ErrorActionPreference = $previous
    }
}

function Initialize-ManagedAvd {
param([Parameter(Mandatory = $true)][string]$RepoRoot)
if (-not (Test-EmulatorReady)) {
    # Un reinicio de ADB puede provocar una ausencia momentánea. No
    # terminar el AVD de inmediato; observar tres veces antes de intervenir.
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        Start-Sleep -Seconds 2
        if (Test-EmulatorReady) { break }
    }
}

if (-not (Test-EmulatorReady)) {
    $state = Get-SerialState
    if ($state -eq 'unknown') {
        throw 'ADB no responde; se reintentará sin terminar otros dispositivos.'
    }
    # Un AVD que ADB todavía ve como online puede seguir arrancando.
    # No hay motivo para matarlo cuando simplemente no terminó boot.
    if ($state -eq 'missing' -or $state -eq 'offline') {
        Assert-AvdAvailableForStartup $RepoRoot
        $owned = @(Get-ManagedAvdProcesses)
        $ownedPids = @($owned | ForEach-Object { $_.ProcessId })
        if (@(Get-EmulatorPortProcesses | Where-Object {
            $_.ProcessId -notin $ownedPids
        }).Count -gt 0) {
            throw 'Puerto AVD ocupado por proceso de propiedad no verificada.'
        }
        $wrappers = @($owned | Where-Object { $_.Name -eq 'emulator.exe' })
        if ($wrappers.Count -gt 0 -and -not (Test-ManagedQemuPresent)) {
            # Un launcher puede sobrevivir a un crash de QEMU. Dar tiempo
            # al arranque antes de liberar solo ese wrapper, nunca su arbol.
            for ($attempt = 0; $attempt -lt 10; $attempt++) {
                Start-Sleep -Seconds 1
                if ((Test-EmulatorReady) -or (Test-ManagedQemuPresent)) { break }
            }
            foreach ($process in $wrappers) {
                if ((Test-EmulatorReady) -or (Test-ManagedQemuPresent)) { break }
                # F5 puede haber empezado durante la espera del wrapper.
                Assert-AvdAvailableForStartup $RepoRoot
                $current = Get-CimInstance Win32_Process -Filter "ProcessId=$($process.ProcessId)"
                if ($current -and $current.CreationDate -eq $process.CreationDate -and
                    $current.CommandLine -eq $process.CommandLine -and
                    $current.Name -eq 'emulator.exe' -and
                    @(Get-ManagedAvdProcesses | Where-Object {
                        $_.ProcessId -eq $current.ProcessId
                    }).Count -eq 1 -and -not (Test-ManagedQemuPresent)) {
                    & taskkill.exe /PID $process.ProcessId /F 2>$null | Out-Null
                }
            }
            # Esperar la salida del wrapper; QEMU vivo siempre se conserva.
            for ($attempt = 0; $attempt -lt 10; $attempt++) {
                if (@(Get-ManagedAvdProcesses).Count -eq 0) { break }
                if (Test-ManagedQemuPresent) { break }
                Start-Sleep -Seconds 1
            }
        }
    }

    $avds = @(
        & $emulator -list-avds |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Trim() }
    )

    if ($AvdName -notin $avds) {
        Write-Host "Primera ejecución: creando $AvdName..."
        $args = @('create','avd','-n',$AvdName,'-k',$SystemImage,'--force')
        'no' | & $avdmanager @args
        if ($LASTEXITCODE -ne 0) {
            throw "No se pudo crear $AvdName con $SystemImage."
        }
    }

    # No duplicar un QEMU vivo aunque ADB no lo vea. Solo arrancar cuando
    # no quede proceso propio ni otro proceso ocupando el puerto.
    $currentState = Get-SerialState
    if ($currentState -eq 'unknown') {
        throw 'ADB no responde; se reintentará sin terminar otros dispositivos.'
    }
    $alreadyConnected = $currentState -eq 'device'
    $existing = @(Get-ManagedAvdProcesses)
    if (-not $alreadyConnected -and $existing.Count -eq 0) {
        Assert-AvdAvailableForStartup $RepoRoot
        if (@(Get-EmulatorPortProcesses).Count -gt 0) {
            throw 'Puerto AVD ocupado por proceso de propiedad no verificada.'
        }
        Write-Host "Arrancando $AvdName..."
        Start-Process -FilePath $emulator -ArgumentList @(
            '-avd', $AvdName,
            '-port', "$port",
            '-no-window',
            '-no-boot-anim',
            # QEMU 37.2.12 cae con Vulkan/Lavapipe en este host Windows.
            # El arranque frio por si solo reprodujo el mismo crash.
            # No cargar ni guardar estado grafico Vulkan entre sesiones.
            '-no-snapshot',
            '-feature', '-Vulkan'
        ) -WindowStyle Hidden | Out-Null
    }

    for ($i = 0; $i -lt 180; $i++) {
        if (Test-EmulatorReady) { break }
        Start-Sleep -Seconds 1
    }
}

if (-not (Test-EmulatorReady)) {
    throw 'El Android virtual de AI-APPS no terminó de arrancar.'
}

Write-Host "Android preparado: $Serial" -ForegroundColor Green
Write-Output "AI_APPS_ANDROID_SERIAL=$Serial"
}

Initialize-ManagedAvd -RepoRoot (Split-Path $PSScriptRoot -Parent)
