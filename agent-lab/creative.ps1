param(
    [string]$Idea,
    [string]$Room,
    [ValidateSet('openai', 'gemini')][string]$Provider = 'openai',
    [string]$Model,
    [ValidateRange(1, 3)][int]$Voices = 3,
    [switch]$Flutter,
    [switch]$Build,
    [switch]$Android,
    [string]$CodexPath
)
$ErrorActionPreference = 'Stop'
$python = Join-Path $PSScriptRoot '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw 'Instala primero agent-lab con install.ps1.' }
$arguments = @('-B', (Join-Path $PSScriptRoot 'creative.py'), '--voices', "$Voices", '--provider', $Provider)
if ($Idea) { $arguments += @('--idea', $Idea) }
if ($Room) { $arguments += @('--room', (Resolve-Path -LiteralPath $Room).Path) }
if ($Model) { $arguments += @('--model', $Model) }
if ($Flutter) { $arguments += '--flutter' }
if ($Build) { $arguments += '--build' }
if ($Android) { $arguments += '--android' }
if ($CodexPath) { $arguments += @('--codex', $CodexPath) }
& $python @arguments
exit $LASTEXITCODE
