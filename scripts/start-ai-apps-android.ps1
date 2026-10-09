param()

$ErrorActionPreference = 'Stop'

$AvdName = 'AI_APPS_Dev'
$Serial = 'emulator-5554'
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

if (-not (Test-EmulatorReady)) {
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

    $alreadyConnected = @(
        & $adb devices |
            Where-Object { $_ -match "^$([regex]::Escape($Serial))\s+(device|offline)\s*$" }
    ).Count -gt 0

    if (-not $alreadyConnected) {
        Write-Host "Arrancando $AvdName..."
        Start-Process -FilePath $emulator -ArgumentList @(
            '-avd', $AvdName,
            '-port', '5554',
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
