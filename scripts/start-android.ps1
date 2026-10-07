param(
    [string]$Device = ''
)

$ErrorActionPreference = 'Stop'

# Shared AI-APPS Android helper.
# It prepares a physical Android device already paired with ADB.
# It never starts an emulator.

$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }

$adb = Join-Path $sdk 'platform-tools\adb.exe'

if (-not (Test-Path -LiteralPath $adb)) {
    throw "ADB not found: $adb"
}

function Get-ConnectedAndroidDevices {
    $output = & $adb devices

    if ($LASTEXITCODE -ne 0) {
        throw 'Could not query ADB devices.'
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

function Connect-PairedWirelessDevices {
    $mdns = & $adb mdns services 2>$null

    foreach ($line in @($mdns)) {
        if ($line -notmatch '_adb-tls-connect\._tcp') { continue }

        $match = [regex]::Match(
            $line,
            '(?<endpoint>(?:\d{1,3}\.){3}\d{1,3}:\d+)'
        )

        if (-not $match.Success) { continue }

        & $adb connect $match.Groups['endpoint'].Value | Out-Null
    }
}

$physical = @(Get-PhysicalAndroidDevices)

if ($physical.Count -eq 0) {
    Connect-PairedWirelessDevices
    Start-Sleep -Milliseconds 750
    $physical = @(Get-PhysicalAndroidDevices)
}

if (-not [string]::IsNullOrWhiteSpace($Device)) {
    if ($Device -notin $physical) {
        throw "Requested physical Android device is not connected: $Device"
    }
    $serial = $Device
}
elseif ($physical.Count -eq 1) {
    $serial = $physical[0]
}
elseif ($physical.Count -gt 1) {
    $wireless = @(
        $physical |
            Where-Object { $_ -match '_adb-tls-connect\._tcp$' }
    )

    if ($wireless.Count -eq 1) {
        $serial = $wireless[0]
    }
    else {
        throw 'Multiple physical Android devices are connected. Specify one with -Device.'
    }
}
else {
    throw 'No physical Android device is connected. Enable wireless debugging on the Pixel 9a and try again.'
}

Write-Host "Physical Android device selected: $serial"
Write-Host 'Waiting for Android to be ready...'

$ready = $false

for ($attempt = 0; $attempt -lt 30; $attempt++) {
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

    Start-Sleep -Seconds 1
}

if (-not $ready) {
    throw "Android is not ready on $serial."
}

$emulators = @(
    Get-ConnectedAndroidDevices |
        Where-Object { $_ -match '^emulator-\d+$' }
)

foreach ($emulatorId in $emulators) {
    & $adb -s $emulatorId emu kill 2>$null | Out-Null
}

Write-Host "Android ready: $serial" -ForegroundColor Green
Write-Output "AI_APPS_ANDROID_SERIAL=$serial"
