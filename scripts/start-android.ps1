param(
    [string]$Device = 'emulator-5554',
    [string]$AvdName = 'Medium_Phone'
)

$ErrorActionPreference = 'Stop'

# Herramienta compartida de AI-APPS.
# No conoce ni ejecuta ninguna aplicación Flutter.

$sdk = $env:ANDROID_HOME

if (-not $sdk) {
    $sdk = $env:ANDROID_SDK_ROOT
}

if (-not $sdk) {
    $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
}

$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'

if (-not (Test-Path -LiteralPath $adb)) {
    throw "No se encuentra ADB: $adb"
}

function Get-ConnectedEmulators {

    param([switch]$ReadyOnly)

    $statePattern = if ($ReadyOnly) { 'device' } else { 'device|offline' }

    $output = & $adb devices

    if ($LASTEXITCODE -ne 0) {
        throw 'No se pudo consultar ADB.'
    }

    @(
        $output |
            Where-Object {
                $_ -match "^\s*(emulator-\d+)\s+($statePattern)\s*$"
            } |
            ForEach-Object {
                ($_.Trim() -split '\s+')[0]
            }
    )
}

function Select-Emulator {

    param(
        [string[]]$Connected,
        [string]$Preferred
    )

    if ($Preferred -in $Connected) {
        return $Preferred
    }

    if ($Connected.Count -eq 1) {
        return $Connected[0]
    }

    if ($Connected.Count -gt 1) {
        throw 'Hay varios emuladores conectados. Indica el dispositivo mediante -Device.'
    }

    return $null
}

# ------------------------------------------------------------
# REUTILIZAR ANDROID SI YA ESTÁ FUNCIONANDO
# ------------------------------------------------------------

$connected = @(Get-ConnectedEmulators)

$serial = Select-Emulator `
    -Connected $connected `
    -Preferred $Device

if ($serial) {

    Write-Host "Reutilizando emulador: $serial"

}
else {

    # --------------------------------------------------------
    # INICIAR UN EMULADOR NUEVO SIN VENTANA EXTERNA
    # --------------------------------------------------------

    if (-not (Test-Path -LiteralPath $emulator)) {
        throw "No se encuentra Android Emulator: $emulator"
    }

    $avds = @(
        & $emulator -list-avds |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            } |
            ForEach-Object {
                $_.Trim()
            }
    )

    if ($LASTEXITCODE -ne 0) {
        throw 'No se pudo consultar la lista de dispositivos virtuales.'
    }

    if ($AvdName -notin $avds) {

        if ($avds.Count -eq 1) {

            $AvdName = $avds[0]

        }
        else {

            throw "No se encuentra el AVD solicitado. Disponibles: $($avds -join ', ')"

        }
    }

    Write-Host "Iniciando Android sin ventana externa: $AvdName"

    Start-Process `
        -FilePath $emulator `
        -ArgumentList @(
            '-avd'
            $AvdName
            '-no-window'
        ) `
        -WindowStyle Hidden | Out-Null
}

# ------------------------------------------------------------
# ESPERAR A QUE ANDROID TERMINE DE ARRANCAR
# ------------------------------------------------------------

Write-Host 'Esperando a que Android esté preparado...'

$ready = $false

for ($attempt = 0; $attempt -lt 120; $attempt++) {

    $connected = @(Get-ConnectedEmulators)

    $serial = Select-Emulator `
        -Connected $connected `
        -Preferred $Device

    if ($serial) {

        # Un emulador offline existe, pero aún no admite comandos shell.
        if ($serial -in @(Get-ConnectedEmulators -ReadyOnly)) {

            $boot = ''

            try {
                $boot = (
                    & $adb -s $serial shell getprop sys.boot_completed 2>$null |
                        Out-String
                ).Trim()
            }
            catch {
                # ADB puede pasar a offline entre comprobar y consultar.
                $boot = ''
            }

            if ($LASTEXITCODE -eq 0 -and $boot -eq '1') {

                $ready = $true
                break

            }
        }
    }

    Start-Sleep -Seconds 2
}

if (-not $ready) {
    throw 'Android no terminó de arrancar durante los 240 segundos de espera.'
}

Write-Host "Android preparado: $serial" -ForegroundColor Green

# La extensión de VS Code utiliza este resultado para abrir
# exactamente el dispositivo que acaba de prepararse.

Write-Output "AI_APPS_ANDROID_SERIAL=$serial"