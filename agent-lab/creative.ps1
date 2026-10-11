param(
    [string]$Idea,
    [string]$TextFile,
    [string]$Image,
    [string]$SeedZip,
    [string]$Room,
    [switch]$Latest,
    [switch]$Lista,
    [string]$Model,
    [string]$CodexPath,
    [ValidateRange(1, 100)][int]$Rounds = 10,
    [ValidateRange(60, 3600)][int]$TimeoutSeconds = 900,
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
$flutterBin = Join-Path $env:USERPROFILE 'development\flutter\bin'
if (-not (Get-Command flutter.bat -ErrorAction SilentlyContinue) -and
    (Test-Path -LiteralPath (Join-Path $flutterBin 'flutter.bat'))) {
    $env:PATH = "$flutterBin;$env:PATH"
}
$python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw 'No se encuentra Python de agent-lab.' }
$arguments = @('-B', (Join-Path $PSScriptRoot 'creative.py'),
               '--rounds', "$Rounds", '--timeout', "$TimeoutSeconds")
if ($Idea) { $arguments += @('--idea', $Idea) }
if ($TextFile) { $arguments += @('--text-file', (Resolve-Path -LiteralPath $TextFile).Path) }
if ($Image) { $arguments += @('--image', (Resolve-Path -LiteralPath $Image).Path) }
if ($SeedZip) {
    $source = (Resolve-Path -LiteralPath $SeedZip -ErrorAction Stop).Path
    $name = [IO.Path]::GetFileName($source)
    if ($name -cnotmatch '^[a-zA-Z0-9_.-]{1,80}\.zip$') {
        throw 'Se requiere un archivo ZIP con nombre seguro.'
    }
    if ((Get-Item -LiteralPath $source).Length -gt 5MB) { throw 'El ZIP supera 5 MiB.' }
    $storage = Join-Path $PSScriptRoot 'seeds'
    New-Item -ItemType Directory -Force -Path $storage | Out-Null
    $target = Join-Path $storage $name
    if ([IO.Path]::GetFullPath($source) -ine [IO.Path]::GetFullPath($target)) {
        if (Test-Path -LiteralPath $target) {
            if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne
                (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash) {
                throw 'Ya existe una semilla versionada con otro contenido.'
            }
        } else {
            Copy-Item -LiteralPath $source -Destination $target
        }
    }
    $arguments += @('--seed-zip', $target)
}
if ($Room) { $arguments += @('--room', (Resolve-Path -LiteralPath $Room).Path) }
if ($Latest) { $arguments += '--latest' }
if ($Lista) { $arguments += '--list-rooms' }
if ($Model) { $arguments += @('--model', $Model) }
if ($CodexPath) { $arguments += @('--codex', $CodexPath) }
if ($Feedback) { $arguments += @('--feedback', $Feedback) }
if ($Flutter) { $arguments += '--flutter' }
if ($Build) { $arguments += '--build' }
if ($Android) { $arguments += '--android' }
if ($Probe) { $arguments += '--probe' }
if ($CostOnly) { $arguments += '--cost-only' }
if ($Transcript) { $arguments += '--transcript' }
if ($Discard) { $arguments += '--discard' }
& $python @arguments
exit $LASTEXITCODE
