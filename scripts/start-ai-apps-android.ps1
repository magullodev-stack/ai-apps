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

# Solo el AVD reservado, verificado por nombre de proceso, nombre del AVD
# Y puerto, puede cerrarse. Nunca reiniciar globalmente el servidor ADB.
function Get-ManagedAvdProcesses {
    $avdArg = '(?i)(^|\s)-avd(?:\s+|=)"?' + [regex]::Escape($AvdName) + '"?(?=\s|$)'
    $portArg = '(?i)(^|\s)-port(?:\s+|=)"?' + [regex]::Escape([string]$port) + '"?(?=\s|$)'
    @(
        Get-CimInstance Win32_Process | Where-Object {
            $_.Name -in @('emulator.exe', 'qemu-system-x86_64.exe',
                'qemu-system-aarch64.exe') -and
            $_.CommandLine -match $avdArg -and
            $_.CommandLine -match $portArg
        }
    )
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
    $terminatedReservedAvd = $false
    # Un AVD que ADB todavía ve como online puede seguir arrancando.
    # No hay motivo para matarlo cuando simplemente no terminó boot.
    if ($state -eq 'missing' -or $state -eq 'offline') {
        $owned = @(Get-ManagedAvdProcesses)
        if ($owned.Count -gt 0) {
            foreach ($process in $owned) {
                $current = Get-CimInstance Win32_Process -Filter "ProcessId=$($process.ProcessId)"
                if ($current -and $current.CreationDate -eq $process.CreationDate -and
                    $current.CommandLine -eq $process.CommandLine -and
                    @(Get-ManagedAvdProcesses | Where-Object {
                        $_.ProcessId -eq $current.ProcessId
                    }).Count -eq 1) {
                    & taskkill.exe /PID $process.ProcessId /T /F 2>$null | Out-Null
                }
            }
            # Nunca arrancar un segundo AVD hasta comprobar que el antiguo
            # ha terminado realmente.
            for ($attempt = 0; $attempt -lt 10; $attempt++) {
                if (@(Get-ManagedAvdProcesses).Count -eq 0) { break }
                Start-Sleep -Seconds 1
            }
            if (@(Get-ManagedAvdProcesses).Count -gt 0) {
                throw 'El AVD reservado sigue activo; no se inicia otro emulador.'
            }
            $terminatedReservedAvd = $true
        } else {
            # Si hay un proceso ocupando el puerto pero NO podemos demostrar
            # que es AI_APPS_Dev, no crear otro AVD. Si no queda ninguno,
            # un registro 'offline' de ADB no impide arrancar uno nuevo.
            $portArg = '(?i)(^|\s)-port(?:\s+|=)"?' +
                [regex]::Escape([string]$port) + '"?(?=\s|$)'
            $portOwner = @(Get-CimInstance Win32_Process | Where-Object {
                $_.Name -in @('emulator.exe', 'qemu-system-x86_64.exe',
                    'qemu-system-aarch64.exe') -and
                $_.CommandLine -match $portArg
            })
            if ($portOwner.Count -gt 0) {
                throw 'Puerto AVD ocupado por proceso de propiedad no verificada.'
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

    # 'offline' no significa conectado: tras cerrar nuestro AVD
    # debe iniciarse otra instancia, aunque ADB aún conserve esa fila.
    $alreadyConnected = (Get-SerialState) -eq 'device'

    if ($terminatedReservedAvd -or -not $alreadyConnected) {
        Write-Host "Arrancando $AvdName..."
        Start-Process -FilePath $emulator -ArgumentList @(
            '-avd', $AvdName,
            '-port', "$port",
            '-no-window',
            '-no-boot-anim'
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
