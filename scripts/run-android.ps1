$ErrorActionPreference = "Stop"

$repo = Split-Path $PSScriptRoot -Parent
$appsDir = Join-Path $repo "apps"
$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk" }
$adb = Join-Path $sdk "platform-tools\adb.exe"
$emulator = Join-Path $sdk "emulator\emulator.exe"
$flutterCommand = Get-Command flutter.bat -ErrorAction SilentlyContinue
$flutter = if ($flutterCommand) {
    $flutterCommand.Source
} else {
    Join-Path $env:USERPROFILE "development\flutter\bin\flutter.bat"
}

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

# Detectar un emulador ya encendido.
function Get-AndroidEmulator {
    $lines = & $adb devices
    if ($LASTEXITCODE -ne 0) {
        throw "No se han podido consultar los dispositivos Android."
    }

    foreach ($line in $lines) {
        if ($line -match '^(emulator-\d+)\s+device\b') {
            return $Matches[1]
        }
    }

    return $null
}

$previousAdbSocket = $env:ADB_SERVER_SOCKET
try {
    # Usar ADB local durante esta ejecucion y restaurar despues el entorno.
    Remove-Item Env:ADB_SERVER_SOCKET -ErrorAction SilentlyContinue
    & $adb start-server | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "No se ha podido iniciar ADB para Windows."
    }

    $device = Get-AndroidEmulator
    if (-not $device) {
        if (-not (Test-Path $emulator)) {
            throw "No encuentro el emulador de Android: $emulator"
        }

        $avds = @(& $emulator -list-avds)
        if ($LASTEXITCODE -ne 0 -or $avds.Count -eq 0) {
            throw "No hay dispositivos virtuales disponibles. Crea uno en Android Studio."
        }
        $avd = $avds[0].Trim()
        Write-Host "Iniciando emulador Android: $avd"
        Start-Process -FilePath $emulator -ArgumentList @("-avd", $avd) -WindowStyle Hidden
    }

    Write-Host "Esperando a Android..."
    $ready = $false
    for ($i = 0; $i -lt 120; $i++) {
        $device = Get-AndroidEmulator
        if ($device) {
            $boot = & $adb -s $device shell getprop sys.boot_completed 2>$null
            if ($LASTEXITCODE -eq 0 -and "$boot".Trim() -eq "1") {
                $ready = $true
                break
            }
        }
        Start-Sleep -Seconds 2
    }
    if (-not $ready) {
        throw "Android no ha terminado de arrancar."
    }

    Push-Location $app.FullName
    try {
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
    } finally {
        Pop-Location
    }
} finally {
    if ($null -eq $previousAdbSocket) {
        Remove-Item Env:ADB_SERVER_SOCKET -ErrorAction SilentlyContinue
    } else {
        $env:ADB_SERVER_SOCKET = $previousAdbSocket
    }
}
