$ErrorActionPreference = "Stop"

$repo = Split-Path $PSScriptRoot -Parent
$appsDir = Join-Path $repo "apps"
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$adb = Join-Path $sdk "platform-tools\adb.exe"
$emulator = Join-Path $sdk "emulator\emulator.exe"
$flutter = Join-Path $env:USERPROFILE "development\flutter\bin\flutter.bat"

# Usar exclusivamente las herramientas de Windows.
Remove-Item Env:ADB_SERVER_SOCKET -ErrorAction SilentlyContinue

if (-not (Test-Path $flutter)) {
    throw "No encuentro Flutter para Windows: $flutter"
}
if (-not (Test-Path $adb)) {
    throw "No encuentro ADB para Windows: $adb"
}

# Descubrir todas las aplicaciones Flutter del repositorio.
$apps = @(
    Get-ChildItem $appsDir -Directory |
    Where-Object {
        (Test-Path (Join-Path $_.FullName "pubspec.yaml")) -and
        (Test-Path (Join-Path $_.FullName "lib\main.dart"))
    } |
    Sort-Object Name
)

if ($apps.Count -eq 0) {
    throw "No se han encontrado aplicaciones Flutter en apps."
}

Write-Host ""
Write-Host "=== AI-APPS: SELECCIONAR APLICACION ==="

for ($i = 0; $i -lt $apps.Count; $i++) {
    Write-Host "$($i + 1). $($apps[$i].Name)"
}

if ($apps.Count -eq 1) {
    $app = $apps[0]
} else {
    $selection = Read-Host "Numero de aplicacion"
    $number = 0

    if (-not [int]::TryParse($selection, [ref]$number) -or
        $number -lt 1 -or $number -gt $apps.Count) {
        throw "Seleccion no valida."
    }

    $app = $apps[$number - 1]
}

Write-Host ""
Write-Host "Aplicacion: $($app.Name)"

# Preparar ADB nativo de Windows.
& $adb start-server | Out-Null

# Detectar un emulador ya encendido.
function Get-AndroidEmulator {
    $lines = & $adb devices

    foreach ($line in $lines) {
        if ($line -match '^(emulator-\d+)\s+device\b') {
            return $Matches[1]
        }
    }

    return $null
}

$device = Get-AndroidEmulator

if (-not $device) {
    if (-not (Test-Path $emulator)) {
        throw "No encuentro el emulador de Android."
    }

    Write-Host "Iniciando emulador Android..."
    Start-Process -FilePath $emulator -ArgumentList @("-avd", "Medium_Phone")
}

Write-Host "Esperando a Android..."

$ready = $false

for ($i = 0; $i -lt 120; $i++) {
    $device = Get-AndroidEmulator

    if ($device) {
        $boot = & $adb -s $device shell getprop sys.boot_completed 2>$null

        if ("$boot".Trim() -eq "1") {
            $ready = $true
            break
        }
    }

    Start-Sleep -Seconds 2
}

if (-not $ready) {
    throw "Android no ha terminado de arrancar."
}

# Ejecutar la aplicacion elegida desde SU propio proyecto Flutter.
Set-Location $app.FullName

Write-Host "Preparando $($app.Name)..."
& $flutter pub get

if ($LASTEXITCODE -ne 0) {
    throw "No se han podido preparar las dependencias de $($app.Name)."
}

Write-Host "Ejecutando $($app.Name) en $device..."
& $flutter run -d $device

if ($LASTEXITCODE -ne 0) {
    throw "La ejecucion de $($app.Name) ha terminado con un error."
}
