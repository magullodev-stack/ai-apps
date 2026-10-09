$ErrorActionPreference = 'Stop'

$AvdName = 'AI_APPS_Dev'
$SystemImage = 'system-images;android-36;google_apis_playstore;x86_64'

$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }

$emulator = Join-Path $sdk 'emulator\emulator.exe'

function Find-Tool([string]$Name) {
    $latest = Join-Path $sdk "cmdline-tools\latest\bin\$Name"
    if (Test-Path -LiteralPath $latest) { return $latest }
    $root = Join-Path $sdk 'cmdline-tools'
    if (-not (Test-Path -LiteralPath $root)) { return $null }
    return Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object {
            $tool = Join-Path $_.FullName "bin\$Name"
            if (Test-Path -LiteralPath $tool) { $tool }
        } |
        Select-Object -First 1
}

if (-not (Test-Path -LiteralPath $emulator)) {
    throw "No se encuentra Android Emulator: $emulator"
}

$avdManager = Find-Tool 'avdmanager.bat'

if (-not $avdManager) {
    throw 'Falta Android SDK Command-line Tools (avdmanager).'
}

$existing = @(& $emulator -list-avds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })

if ($AvdName -in $existing) {
    Write-Host "Android de desarrollo ya preparado: $AvdName"
    exit 0
}

Write-Host 'Preparando Android de desarrollo por primera vez...'

$createArgs = @('create','avd','-n',$AvdName,'-k',$SystemImage,'--force')
'no' | & $avdManager @createArgs
if ($LASTEXITCODE -ne 0) { throw "No se pudo crear $AvdName." }

Write-Host "Android de desarrollo creado: $AvdName" -ForegroundColor Green
