param(
    [string]$Device = 'emulator-5554',
    [string]$Model = 'gpt-4.1-mini',
    [string]$CatalogModel = 'gpt-5.6-luna',
    [Alias('TerraModel')]
    [string]$FactualModel = 'gpt-5.6-terra',
    [switch]$VerifyOnly,
    [switch]$StopService
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$flutterCommand = Get-Command flutter.bat -ErrorAction SilentlyContinue
$flutter = if ($flutterCommand) { $flutterCommand.Source } else {
    Join-Path $env:USERPROFILE 'development\flutter\bin\flutter.bat'
}
$dart = Join-Path (Split-Path $flutter) 'cache\dart-sdk\bin\dart.exe'
$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$runtime = Join-Path $repo '.ai-apps'
$sessionFile = Join-Path $runtime 'dart-service.json'
$logFile = Join-Path $runtime 'dart-service.log'

function Get-ServiceSession {
    if (-not (Test-Path -LiteralPath $sessionFile)) { return $null }
    try {
        $session = Get-Content -Raw -LiteralPath $sessionFile | ConvertFrom-Json
        $endpoint = [Uri]$session.endpoint
        if ($endpoint.Scheme -ne 'http' -or $endpoint.Host -ne '127.0.0.1') { return $null }
        $health = Invoke-RestMethod -Uri "$($session.endpoint)/health" `
            -Headers @{ Authorization = "Bearer $($session.token)" } -TimeoutSec 2
        if ($health.service -eq 'ai-apps-dart' -and $health.protocol -eq 1 -and
            $health.pid -eq $session.pid) { return $session }
    } catch { }
    return $null
}

function Get-OpenAiKey {
    foreach ($scope in @('Process', 'User', 'Machine')) {
        foreach ($name in @('AI_APPS_AI_API_KEY', 'OPENAI_API_KEY')) {
            $candidate = [Environment]::GetEnvironmentVariable($name, $scope)
            if (-not [string]::IsNullOrWhiteSpace($candidate)) { return $candidate.Trim() }
        }
    }
    $secure = Read-Host 'Clave OpenAI (entrada oculta, solo en memoria del servicio)' -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer).Trim() }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        $secure.Dispose()
    }
}

$session = Get-ServiceSession
if ($StopService) {
    if ($session) {
        $process = Get-Process -Id $session.pid -ErrorAction SilentlyContinue
        $dartExecutables = @($dart, (Join-Path (Split-Path $dart) 'dartvm.exe'))
        if ($process -and $process.Path -in $dartExecutables) {
            Stop-Process -Id $process.Id
            Remove-Item -LiteralPath $sessionFile
            Write-Host 'Servicio Dart detenido.'
        } else { throw 'El proceso no coincide con el servicio Dart; no se ha detenido.' }
    } else { Write-Host 'No hay un servicio Dart activo de esta sesión.' }
    return
}
if (-not (Test-Path -LiteralPath $flutter) -or -not (Test-Path -LiteralPath $dart)) {
    throw 'No se encuentra la instalación de Flutter y Dart.'
}
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
if (-not $session) {
    $key = Get-OpenAiKey
    if ([string]::IsNullOrWhiteSpace($key)) { throw 'No se ha proporcionado una clave OpenAI.' }
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    $token = [Convert]::ToBase64String($bytes)
    $previous = @{}
    foreach ($name in @('AI_APPS_AI_API_KEY','OPENAI_API_KEY','AI_APPS_GAME_TOKEN','AI_APPS_READY_FILE')) {
        $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    try {
        $env:AI_APPS_AI_API_KEY = $key
        Remove-Item Env:OPENAI_API_KEY -ErrorAction SilentlyContinue
        $env:AI_APPS_GAME_TOKEN = $token
        $env:AI_APPS_READY_FILE = $sessionFile
        if (Test-Path -LiteralPath $sessionFile) { Remove-Item -LiteralPath $sessionFile }
        $serverScript = Join-Path $repo 'ai\dart_service\bin\server.dart'
        $serviceProcess = Start-Process -FilePath $dart -ArgumentList @('"' + $serverScript + '"') `
            -WorkingDirectory $repo -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $runtime 'dart-service.stdout.log') `
            -RedirectStandardError $logFile
    } finally {
        foreach ($name in $previous.Keys) {
            [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
        }
        $key = $null
        $token = $null
    }
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        $session = Get-ServiceSession
        if ($session) { break }
        if ($serviceProcess.HasExited) { throw "El servicio ha terminado. Consulta $logFile" }
        Start-Sleep -Milliseconds 250
    }
    if (-not $session) {
        if (-not $serviceProcess.HasExited) { Stop-Process -Id $serviceProcess.Id }
        throw "El servicio Dart no está disponible. Consulta $logFile"
    }
}
Write-Host "Servicio Dart preparado: $($session.endpoint)"

# OpenAI credentials are never inherited by Flutter or passed as dart-defines.
$previousClientEnv = @{}
foreach ($name in @('AI_APPS_AI_API_KEY','OPENAI_API_KEY','AI_APPS_GAME_TOKEN','AI_APPS_AI_URL','ADB_SERVER_SOCKET')) {
    $previousClientEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
try {
    Remove-Item Env:AI_APPS_AI_API_KEY, Env:OPENAI_API_KEY, Env:ADB_SERVER_SOCKET -ErrorAction SilentlyContinue
    Push-Location (Join-Path $repo 'apps\quizai')
    try {
        & $flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Falló flutter pub get.' }
        if ($VerifyOnly) {
            $receipt = Join-Path $runtime 'quiz10-verification.json'
            if (Test-Path -LiteralPath $receipt) { Remove-Item -LiteralPath $receipt }
            $env:AI_APPS_AI_URL = $session.endpoint
            $env:AI_APPS_GAME_TOKEN = $session.token
            & $dart run tool/verify_generation.dart
            if ($LASTEXITCODE -ne 0) { throw "La generación real no superó la validación. Consulta $logFile" }
            @{
                model = 'gpt-4.1-mini'; validatedQuestions = 10
                completedAt = [DateTime]::UtcNow.ToString('o')
            } | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath $receipt
        } else {
            if (-not (Test-Path -LiteralPath $adb)) { throw 'No se encuentra ADB.' }
            # Preferir el dispositivo solicitado; si no existe, utilizar
            # el único emulador conectado. Si no hay ninguno, iniciar
            # el AVD instalado y esperar a que Android termine de arrancar.
            function Get-ConnectedEmulators {
                @(
                    & $adb devices |
                        Where-Object { $_ -match '^emulator-\d+\s+device\s*$' } |
                        ForEach-Object { ($_ -split '\s+')[0] }
                )
            }

            $connected = @(Get-ConnectedEmulators)

            if ($Device -notin $connected) {
                if ($connected.Count -eq 1) {
                    $Device = $connected[0]
                    Write-Host "Emulador conectado: $Device"
                }
                elseif ($connected.Count -gt 1) {
                    throw "Hay varios emuladores conectados. Indica el dispositivo con -Device."
                }
                else {
                    $emulator = Join-Path $sdk 'emulator\emulator.exe'

                    if (-not (Test-Path -LiteralPath $emulator)) {
                        throw "No se encuentra el emulador Android en $emulator"
                    }

                    $avds = @(
                        & $emulator -list-avds |
                            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                    )

                    if ($avds.Count -ne 1) {
                        throw "No hay un emulador único para iniciar. Emuladores instalados: $($avds -join ', ')"
                    }

                    Write-Host "Iniciando emulador Android: $($avds[0])"

                    $emulatorProcess = Start-Process `
                        -FilePath $emulator `
                        -ArgumentList @('-avd', $avds[0]) `
                        -PassThru

                    $found = $false

                    for ($attempt = 0; $attempt -lt 90; $attempt++) {
                        Start-Sleep -Seconds 2
                        $connected = @(Get-ConnectedEmulators)

                        if ($Device -in $connected) {
                            $found = $true
                            break
                        }

                        if ($connected.Count -eq 1) {
                            $Device = $connected[0]
                            $found = $true
                            break
                        }

                        if ($connected.Count -gt 1) {
                            throw 'Hay varios emuladores conectados; no se puede seleccionar uno de forma segura.'
                        }

                        if ($emulatorProcess.HasExited) {
                            throw 'El emulador se cerró durante el arranque.'
                        }
                    }

                    if (-not $found) {
                        throw 'El emulador no apareció en ADB durante los 180 segundos de espera.'
                    }

                    Write-Host "Emulador detectado: $Device"
                }
            }

            # Estar conectado a ADB no significa que Android haya
            # terminado de arrancar. Esperar a sys.boot_completed.
            $booted = $false

            for ($attempt = 0; $attempt -lt 90; $attempt++) {
                $state = (& $adb -s $Device get-state 2>$null | Out-String).Trim()

                if ($state -eq 'device') {
                    $boot = (& $adb -s $Device shell getprop sys.boot_completed 2>$null |
                        Out-String).Trim()

                    if ($boot -eq '1') {
                        $booted = $true
                        break
                    }
                }

                Start-Sleep -Seconds 2
            }

            if (-not $booted) {
                throw "Android no terminó de arrancar en $Device durante los 180 segundos de espera."
            }

            Write-Host "Android preparado: $Device"
            $port = ([Uri]$session.endpoint).Port
            & $adb -s $Device reverse tcp:8787 "tcp:$port"
            if ($LASTEXITCODE -ne 0) { throw 'No se pudo establecer adb reverse.' }
            $definesFile = Join-Path $runtime 'quiz10-defines.json'
            @{
                AI_APPS_AI_URL = 'http://127.0.0.1:8787'
                AI_APPS_GAME_TOKEN = $session.token
                AI_APPS_AI_MODEL = $Model
                AI_APPS_CATALOG_MODEL = $CatalogModel
                AI_APPS_FACTUAL_MODEL = $FactualModel
                AI_APPS_TERRA_MODEL = $FactualModel
            } | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath $definesFile
            & $flutter run -d $Device "--dart-define-from-file=$definesFile"
            if ($LASTEXITCODE -ne 0) { throw 'Flutter terminó con un error.' }
        }
    } finally { Pop-Location }
} finally {
    foreach ($name in $previousClientEnv.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previousClientEnv[$name], 'Process')
    }
}
