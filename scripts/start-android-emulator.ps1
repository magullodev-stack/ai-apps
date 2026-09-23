$ErrorActionPreference = "Stop"

$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$adb = "$sdk\platform-tools\adb.exe"
$emulator = "$sdk\emulator\emulator.exe"

if (-not (Test-Path $adb)) {
    throw "Android ADB no esta disponible."
}

if (-not (Test-Path $emulator)) {
    throw "El emulador Android no esta disponible."
}

& $adb start-server | Out-Null

$devices = & $adb devices

if ($devices -notmatch "emulator-\d+\s+device") {

    Write-Host "Iniciando emulador Android..."

    Start-Process $emulator -ArgumentList "-avd", "Medium_Phone"
}

Write-Host "Esperando a que Android este preparado..."

$ready = $false

for ($i = 0; $i -lt 120; $i++) {

    $devices = & $adb devices

    $match = $devices |
        Select-String '^(emulator-\d+)\s+device\b' |
        Select-Object -First 1

    if ($match) {

        $deviceId = $match.Matches[0].Groups[1].Value

        $boot = & $adb -s $deviceId shell getprop sys.boot_completed

        if ("$boot".Trim() -eq "1") {
            $ready = $true
            break
        }
    }

    Start-Sleep -Seconds 2
}

if (-not $ready) {
    throw "El emulador no ha terminado de arrancar."
}

Write-Host "Android preparado: $deviceId"
