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

function Get-ReadyEmulators {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = & $adb devices 2>$null
        if ($LASTEXITCODE -ne 0) { return @() }
        return @(
            $lines |
                Where-Object { $_ -match '^\s*(emulator-\d+)\s+device\s*$' } |
                ForEach-Object { ($_.Trim() -split '\s+')[0] }
        )
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}

function Get-BootCompleted([string]$Serial) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $value = (& $adb -s $Serial shell getprop sys.boot_completed 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { return $false }
        return $value -eq '1'
    }
    catch {
        return $false
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
}

$connected = @(Get-ReadyEmulators)
$serial = if ($Device -in $connected) { $Device } elseif ($connected.Count -eq 1) { $connected[0] } else { $null }

if (-not $serial) {
    $avds = @(& $emulator -list-avds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
    if ($AvdName -notin $avds) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setup
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar Android de desarrollo.' }
    }

    $emulatorArgs = @('-avd',$AvdName,'-port','5554','-no-window','-no-boot-anim','-netdelay','none','-netspeed','full')
    Start-Process -FilePath $emulator -ArgumentList $emulatorArgs -WindowStyle Hidden | Out-Null
}

for ($attempt = 0; $attempt -lt 180; $attempt++) {
    $connected = @(Get-ReadyEmulators)
    $candidate = if ($Device -in $connected) { $Device } elseif ($connected.Count -eq 1) { $connected[0] } else { $null }

    if ($candidate -and (Get-BootCompleted -Serial $candidate)) {
        Write-Host "Android de desarrollo preparado: $candidate" -ForegroundColor Green
        Write-Output "AI_APPS_ANDROID_SERIAL=$candidate"
        exit 0
    }

    Start-Sleep -Seconds 1
}

throw 'Android de desarrollo no terminó de arrancar.'
