param(
    [string]$Device = 'emulator-5554',
    [string]$AvdName = 'Medium_Phone'
)

$ErrorActionPreference = 'Stop'

$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }

$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'

if (-not (Test-Path -LiteralPath $adb)) {
    throw "No se encuentra ADB: $adb"
}

if (-not (Test-Path -LiteralPath $emulator)) {
    throw "No se encuentra Android Emulator: $emulator"
}

function Get-ConnectedEmulators {
    $output = & $adb devices

    if ($LASTEXITCODE -ne 0) {
        throw 'No se pudo consultar ADB.'
    }

    @(
        $output |
            Where-Object {
                $_ -match '^\s*(emulator-\d+)\s+(device|offline)\s*$'
            } |
            ForEach-Object {
                ($_.Trim() -split '\s+')[0]
            }
    )
}

$connected = @(Get-ConnectedEmulators)
$serial = $null

if ($Device -in $connected) {
    $serial = $Device
}
elseif ($connected.Count -eq 1) {
    $serial = $connected[0]
}
elseif ($connected.Count -gt 1) {
    throw 'Hay varios emuladores conectados. Cierra los sobrantes o indica -Device.'
}

if ($serial) {
    Write-Host "Reutilizando emulador: $serial"
}
else {
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
        throw 'No se pudo consultar la lista de AVD.'
    }

    if ($AvdName -notin $avds) {
        if ($avds.Count -eq 1) {
            $AvdName = $avds[0]
        }
        else {
            throw "No se encuentra el AVD '$AvdName'. Disponibles: $($avds -join ', ')"
        }
    }

    Write-Host "Iniciando emulador headless: $AvdName"

    Start-Process `
        -FilePath $emulator `
        -ArgumentList @(
            '-avd', $AvdName,
            '-no-window',
            '-no-boot-anim',
            '-no-snapshot-save'
        ) `
        -WindowStyle Hidden | Out-Null
}

$ready = $false

for ($attempt = 0; $attempt -lt 120; $attempt++) {
    $connected = @(Get-ConnectedEmulators)

    if (-not $serial) {
        if ($Device -in $connected) {
            $serial = $Device
        }
        elseif ($connected.Count -eq 1) {
            $serial = $connected[0]
        }
    }

    if ($serial -and $serial -in $connected) {
        $state = (& $adb -s $serial get-state 2>$null | Out-String).Trim()

        if ($state -eq 'device') {
            $boot = (
                & $adb -s $serial shell getprop sys.boot_completed 2>$null |
                    Out-String
            ).Trim()

            if ($boot -eq '1') {
                $ready = $true
                break
            }
        }
    }

    Start-Sleep -Seconds 1
}

if (-not $ready) {
    throw 'El emulador Android no terminó de arrancar.'
}

Write-Host "Android preparado: $serial" -ForegroundColor Green
Write-Output "AI_APPS_ANDROID_SERIAL=$serial"
