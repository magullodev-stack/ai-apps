param(
    [string]$Idea,
    [string]$TextFile,
    [string]$Image,
    [string]$SeedZip,
    [string]$Room,
    [switch]$Latest,
    [switch]$Lista,
    [string]$Model,
    [ValidateRange(1, 50)][int]$Rounds = 10,
    [string]$Feedback,
    [switch]$Flutter,
    [switch]$Build,
    [switch]$Android,
    [switch]$Probe,
    [switch]$CostOnly,
    [switch]$Transcript,
    [switch]$Discard
)

$ErrorActionPreference = 'Stop'
if ($Build -and -not $PSBoundParameters.ContainsKey('Rounds')) { $Rounds = 1 }

# Use Flutter already installed on the workstation; no second SDK.
$flutterBin = Join-Path $env:USERPROFILE 'development\flutter\bin'
if (-not (Get-Command flutter.bat -ErrorAction SilentlyContinue) -and
    (Test-Path -LiteralPath (Join-Path $flutterBin 'flutter.bat'))) {
    $env:PATH = "$flutterBin;$env:PATH"
}
$python = Join-Path $PSScriptRoot '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw 'Instala primero agent-lab con install.ps1.' }
$arguments = @('-B', (Join-Path $PSScriptRoot 'creative.py'), '--rounds', "$Rounds")
if ($Idea) { $arguments += @('--idea', $Idea) }
if ($TextFile) { $arguments += @('--text-file', (Resolve-Path -LiteralPath $TextFile).Path) }
if ($Image) { $arguments += @('--image', (Resolve-Path -LiteralPath $Image).Path) }
if ($SeedZip) {
    # Persist user-supplied reference material in Git; the existing autosync
    # publishes this binary just like any other versioned project input.
    $source = (Resolve-Path -LiteralPath $SeedZip -ErrorAction Stop).Path
    $name = [IO.Path]::GetFileName($source)
    if ($name -cnotmatch '^[a-zA-Z0-9_.-]{1,80}\\.zip
if ($Feedback) { $arguments += @('--feedback', $Feedback) }
if ($Room) { $arguments += @('--room', (Resolve-Path -LiteralPath $Room).Path) }
if ($Latest) { $arguments += '--latest' }
if ($Lista) { $arguments += '--list-rooms' }
if ($Model) { $arguments += @('--model', $Model) }
if ($Flutter) { $arguments += '--flutter' }
if ($Build) { $arguments += '--build' }
if ($Android) { $arguments += '--android' }
if ($Probe) { $arguments += '--probe' }
if ($CostOnly) { $arguments += '--cost-only' }
if ($Transcript) { $arguments += '--transcript' }
if ($Discard) { $arguments += '--discard' }

& $python @arguments
exit $LASTEXITCODE
) {
        throw 'El nombre del paquete debe ser seguro y terminar en .zip.'
    }
    if ((Get-Item -LiteralPath $source).Length -gt 5MB) {
        throw 'El paquete de referencia supera los 5 MiB.'
    }
    $storage = Join-Path $PSScriptRoot 'seeds'
    New-Item -ItemType Directory -Force -Path $storage | Out-Null
    $target = Join-Path $storage $name
    if ([IO.Path]::GetFullPath($source) -ine [IO.Path]::GetFullPath($target)) {
        if (Test-Path -LiteralPath $target) {
            if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne
                (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash) {
                throw "La semilla ya está versionada con otro contenido: $target"
            }
        } else {
            Copy-Item -LiteralPath $source -Destination $target
            Write-Host "Semilla original incorporada al repositorio: $target"
        }
    }
    $arguments += @('--seed-zip', $target)
}
if ($Build -and ($SeedZip -or $Image -or $Latest -or $Room)) {
    # Upgrade only on demand. The shared server retains its original port
    # and bearer token, so QuizAI's adb reverse and credentials remain valid.
    $sessionFile = Join-Path (Split-Path $PSScriptRoot -Parent) '.ai-apps\dart-service.json'
    if (Test-Path -LiteralPath $sessionFile) {
        try {
            $session = Get-Content -LiteralPath $sessionFile -Raw | ConvertFrom-Json
            $health = Invoke-RestMethod -Uri "$($session.endpoint)/health" `
                -Headers @{ Authorization = "Bearer $($session.token)" } -TimeoutSec 3
            if ($health.service -eq 'ai-apps-dart' -and
                $health.capabilities.imageInput -ne $true) {
                Write-Host 'Actualizando automáticamente el servicio Dart compartido...'
                & (Join-Path (Split-Path $PSScriptRoot -Parent) 'apps\quizai\run.ps1') -RefreshServiceOnly
                if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                    throw 'No se pudo actualizar el servicio Dart.'
                }
            }
        } catch {
            throw "No se pudo verificar o actualizar el servicio Dart: $($_.Exception.Message)"
        }
    }
}
if ($Feedback) { $arguments += @('--feedback', $Feedback) }
if ($Room) { $arguments += @('--room', (Resolve-Path -LiteralPath $Room).Path) }
if ($Latest) { $arguments += '--latest' }
if ($Lista) { $arguments += '--list-rooms' }
if ($Model) { $arguments += @('--model', $Model) }
if ($Flutter) { $arguments += '--flutter' }
if ($Build) { $arguments += '--build' }
if ($Android) { $arguments += '--android' }
if ($Probe) { $arguments += '--probe' }
if ($CostOnly) { $arguments += '--cost-only' }
if ($Transcript) { $arguments += '--transcript' }
if ($Discard) { $arguments += '--discard' }

& $python @arguments
exit $LASTEXITCODE
