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

if (-not (Test-Path -LiteralPath $adb)) {
    throw "No se encuentra ADB: $adb"
}

if (-not (Test-Path -LiteralPath $emulator)) {
    throw "No se encuentra Android Emulator: $emulator"
}

function Find-AndroidCommandLineTool([string]$Name) {
    $latest = Join-Path $sdk "cmdline-tools\latest\bin\$Name"
    if (Test-Path -LiteralPath $latest) {
        return $latest
    }

    $root = Join-Path $sdk 'cmdline-tools'
    if (-not (Test-Path -LiteralPath $root)) {
        return $null
    }

    $candidate = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object {
            $tool = Join-Path $_.FullName "bin\$Name"
            if (Test-Path -LiteralPath $tool) { $tool }
        } |
        Select-Object -First 1

    return $candidate
}

function Get-ConnectedEmulators {
    @(
        & $adb devices |
            Where-Object {
                $_ -match '^\s*(emulator-\d+)\s+(device|offline)\s*$'
            } |
            ForEach-Object {
                ($_.Trim() -split '\s+')[0]
            }
    )
}

function Get-InstalledSystemImages {
    $root = Join-Path $sdk 'system-images'
    if (-not (Test-Path -LiteralPath $root)) {
        return @()
    }

    $images = @()

    Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^android-(\d+)$' } |
        ForEach-Object {
            $apiDir = $_
            $api = [int]$Matches[1]

            Get-ChildItem -LiteralPath $apiDir.FullName -Directory -ErrorAction SilentlyContinue |
                ForEach-Object {
                    $tagDir = $_
                    $tag = $tagDir.Name

                    Get-ChildItem -LiteralPath $tagDir.FullName -Directory -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -eq 'x86_64' } |
                        ForEach-Object {
                            $preference = switch ($tag) {
                                'google_apis_playstore' { 3 }
                                'google_apis' { 2 }
                                'default' { 1 }
                                default { 0 }
                            }

                            $images += [pscustomobject]@{
                                Package = "system-images;android-$api;$tag;x86_64"
                                Api = $api
                                Preference = $preference
                            }
                        }
                }
        }

    return @(
        $images |
            Sort-Object @{ Expression = 'Preference'; Descending = $true },
                        @{ Expression = 'Api'; Descending = $true }
    )
}

function Get-BestAvailableSystemImage([string]$SdkManager) {
    Write-Host 'Buscando una imagen Android disponible para el emulador...'

    $listing = & $SdkManager "--sdk_root=$sdk" --list
    if ($LASTEXITCODE -ne 0) {
        throw 'No se pudo consultar sdkmanager.'
    }

    $candidates = @()

    foreach ($line in $listing) {
        $match = [regex]::Match(
            $line,
            '^\s*(system-images;android-(?<api>\d+);(?<tag>google_apis_playstore|google_apis);x86_64)\s+\|'
        )

        if (-not $match.Success) { continue }

        $tag = $match.Groups['tag'].Value
        $candidates += [pscustomobject]@{
            Package = $match.Groups[1].Value
            Api = [int]$match.Groups['api'].Value
            Preference = if ($tag -eq 'google_apis_playstore') { 2 } else { 1 }
        }
    }

    $best = $candidates |
        Sort-Object @{ Expression = 'Preference'; Descending = $true },
                    @{ Expression = 'Api'; Descending = $true } |
        Select-Object -First 1

    if (-not $best) {
        throw 'No se encontró ninguna system image Android x86_64 compatible.'
    }

    return $best.Package
}

function Ensure-DevelopmentAvd([string]$Name) {
    $avdManager = Find-AndroidCommandLineTool 'avdmanager.bat'
    $sdkManager = Find-AndroidCommandLineTool 'sdkmanager.bat'

    if (-not $avdManager -or -not $sdkManager) {
        throw 'Faltan Android SDK Command-line Tools (sdkmanager/avdmanager).'
    }

    $avds = @(
        & $emulator -list-avds |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Trim() }
    )

    if ($Name -in $avds) {
        return $Name
    }

    if ($avds.Count -gt 0) {
        $existing = $avds[0]
        Write-Host "Reutilizando AVD existente: $existing"
        return $existing
    }

    $installed = @(Get-InstalledSystemImages)
    $package = if ($installed.Count -gt 0) {
        $installed[0].Package
    } else {
        Get-BestAvailableSystemImage -SdkManager $sdkManager
    }

    if ($installed.Count -eq 0) {
        Write-Host "Instalando una sola vez la imagen Android: $package"
        1..50 | ForEach-Object { 'y' } | & $sdkManager "--sdk_root=$sdk" $package

        if ($LASTEXITCODE -ne 0) {
            throw "Falló la instalación de $package."
        }
    }

    $deviceListing = & $avdManager list device
    $deviceIds = @(
        $deviceListing |
            ForEach-Object {
                $match = [regex]::Match($_, 'id:\s+\d+\s+or\s+"([^"]+)"')
                if ($match.Success) { $match.Groups[1].Value }
            }
    )

    $preferred = @()
    $preferred += @($deviceIds | Where-Object { $_ -match '^pixel_9' })
    $preferred += @($deviceIds | Where-Object { $_ -match '^pixel_8' })
    $preferred += @($deviceIds | Where-Object { $_ -match '^pixel_7' })
    $preferred += @($deviceIds | Where-Object { $_ -match '^pixel_6' })
    $preferred += @($deviceIds | Where-Object { $_ -match '^pixel' })
    $preferred += $deviceIds
    $deviceId = $preferred | Select-Object -First 1

    if (-not $deviceId) {
        throw 'avdmanager no devolvió ningún perfil de dispositivo Android.'
    }

    Write-Host "Creando una sola vez el AVD '$Name' con $package ($deviceId)..."

    $createArgs = @(
        'create', 'avd',
        '-n', $Name,
        '-k', $package,
        '-d', $deviceId,
        '--force'
    )

    'no' | & $avdManager @createArgs

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo crear el AVD '$Name'."
    }

    return $Name
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
    throw 'Hay varios emuladores Android conectados. Cierra los sobrantes.'
}

if ($serial) {
    Write-Host "Reutilizando emulador ya conectado: $serial"
}
else {
    $avd = Ensure-DevelopmentAvd -Name $AvdName

    Write-Host "Iniciando emulador headless: $avd"

    $emulatorArgs = @(
        '-avd', $avd,
        '-no-window',
        '-no-boot-anim',
        '-netdelay', 'none',
        '-netspeed', 'full'
    )

    Start-Process -FilePath $emulator -ArgumentList $emulatorArgs -WindowStyle Hidden | Out-Null
}

$ready = $false

for ($attempt = 0; $attempt -lt 180; $attempt++) {
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

Write-Host "Android de desarrollo preparado: $serial" -ForegroundColor Green
Write-Output "AI_APPS_ANDROID_SERIAL=$serial"
