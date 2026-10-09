param(
    [string]$Device = 'emulator-5554',
    [string]$AvdName = 'AI_APPS_Dev'
)

$ErrorActionPreference = 'Stop'

$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }

$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'
$setup = Join-Path $PSScriptRoot 'setup-android-dev.ps1'

if (-not (Test-Path -LiteralPath $adb)) { throw "No se encuentra ADB: $adb" }
if (-not (Test-Path -LiteralPath $emulator)) { throw "No se encuentra Android Emulator: $emulator" }

$connected = @(& $adb devices | Where-Object { $_ -match '^\s*(emulator-\d+)\s+device\s*$' } | ForEach-Object { ($_.Trim() -split '\s+')[0] })

$serial = if ($Device -in $connected) { $Device } elseif ($connected.Count -eq 1) { $connected[0] } else { $null }

if (-not $serial) {
    $avds = @(& $emulator -list-avds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
    if ($AvdName -notin $avds) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setup
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar Android de desarrollo.' }
    }
    $emulatorArgs = @('-avd',$AvdName,'-no-window','-no-boot-anim','-netdelay','none','-netspeed','full')
    Start-Process -FilePath $emulator -ArgumentList $emulatorArgs -WindowStyle Hidden | Out-Null
}

for ($attempt = 0; $attempt -lt 180; $attempt++) {
    if (-not $serial) {
        $serial = @(& $adb devices | Where-Object { $_ -match '^\s*(emulator-\d+)\s+device\s*$' } | ForEach-Object { ($_.Trim() -split '\s+')[0] }) | Select-Object -First 1
    }
    if ($serial) {
        $boot = (& $adb -s $serial shell getprop sys.boot_completed 2>$null | Out-String).Trim()
        if ($boot -eq '1') {
            Write-Host "Android de desarrollo preparado: $serial" -ForegroundColor Green
            Write-Output "AI_APPS_ANDROID_SERIAL=$serial"
            exit 0
        }
    }
    Start-Sleep -Seconds 1
}

throw 'Android de desarrollo no terminó de arrancar.'
