param(
    [string]$Device = ''
)

$ErrorActionPreference = 'Stop'

# Herramienta compartida de AI-APPS.
# Prepara un dispositivo Android físico ya conectado mediante ADB.
# Nunca inicia un emulador.

$sdk = $env:ANDROID_HOME

if (-not $sdk) {
    $sdk = $env:ANDROID_SDK_ROOT
}

if (-not $sdk) {
    $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
}

$adb = Join-Path $sdk 'platform-tools\adb.exe'

if (-not (Test-Path -LiteralPath $adb)) {
    throw "No se encuentra ADB: $adb"
}

function Get-ConnectedAndroidDevices {
    $output = & $adb devices

    if ($LASTEXITCODE -ne 0) {
        throw 'No se pudo consultar ADB.'
    }

    @(
        $output |
            Where-Object { $_ -match '^\s*\S+\s+device\s*$' } |
            ForEach-Object { ($_.Trim() -split '\s+')[0] }
    )
}

function Get-PhysicalAndroidDevices {
    @(
        Get-ConnectedAndroidDevices |
            Where-Object { $_ -notmatch '^emulator-\d+$' }
    )
}

$physical = @(Get-PhysicalAndroidDevices)

if (-not [string]::IsNullOrWhiteSpace($Device)) {
    if ($Device -notin $physical) {
        throw "El dispositivo Android físico solicitado no está conectado: $Device"
    }

    $serial = $Device
}
elseif ($physical.Count -eq 1) {
    $serial = $physical[0]
}
elseif ($physical.Count -gt 1) {
    # ADB puede publicar el mismo móvil mediante IP y mediante mDNS.
    # Si hay una única identidad inalámbrica estable, se prefiere.
    $wireless = @(
        $physical |
            Where-Object { $_ -match '_adb-tls-connect\._tcp$' }
    )

    if ($wireless.Count -eq 1) {
        $serial = $wireless[0]
    }
    else {
        throw 'Hay varios dispositivos Android físicos conectados. Indica uno mediante -Device.'
    }
}
else {
    throw 'No hay ningún dispositivo Android físico conectado. Conecta el Pixel 9a mediante ADB y vuelve a intentarlo.'
}

Write-Host "Dispositivo Android físico seleccionado: $serial"
Write-Host 'Esperando a que Android esté preparado...'

$ready = $false

for ($attempt = 0; $attempt -lt 30; $attempt++) {
    $state = (& $adb -s $serial get-state 2>$null | Out-String).Trim()

    if ($state -eq 'device') {
        $boot = (& $adb -s $serial shell getprop sys.boot_completed 2>$null |
            Out-String).Trim()

        if ($boot -eq '1') {
            $ready = $true
            break
        }
    }

    Start-Sleep -Seconds 1
}

if (-not $ready) {
    throw "Android no está preparado en $serial."
}

Write-Host "Android preparado: $serial" -ForegroundColor Green
Write-Output "AI_APPS_ANDROID_SERIAL=$serial"
