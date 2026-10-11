param(
    [string]$Idea,
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
