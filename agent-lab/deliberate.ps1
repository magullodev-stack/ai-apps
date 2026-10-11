param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Instruction,
    [string]$SourceRepo,
    [string]$CodexPath,
    [string]$Model,
    [string]$Config,
    [ValidateRange(1, 3600)][int]$TimeoutSeconds = 300,
    [switch]$Flutter,
    [switch]$Android,
    [string]$AndroidProject = '.',
    [string]$AndroidSerial,
    [string]$AndroidAvd,
    [switch]$Offline
)
$ErrorActionPreference = 'Stop'
$python = Join-Path $PSScriptRoot '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw 'Run agent-lab/install.ps1 first.' }
$arguments = @('-B', (Join-Path $PSScriptRoot 'deliberation.py'), '--instruction', $Instruction, '--timeout', "$TimeoutSeconds")
if ($SourceRepo) { $arguments += @('--source', (Resolve-Path -LiteralPath $SourceRepo).Path) }
if ($Model) { $arguments += @('--model', $Model) }
if ($Config) { $arguments += @('--config', (Resolve-Path -LiteralPath $Config).Path) }
if ($Flutter) { $arguments += '--flutter' }
if ($Android) {
    $arguments += @('--android', '--android-project', $AndroidProject)
    if ($AndroidSerial) { $arguments += @('--android-serial', $AndroidSerial) }
    if ($AndroidAvd) { $arguments += @('--android-avd', $AndroidAvd) }
}
if ($Offline) { $arguments += '--offline' }
else {
    if (-not $CodexPath) {
        $command = Get-Command codex -ErrorAction SilentlyContinue
        if ($command) { $CodexPath = $command.Source }
    }
    if (-not $CodexPath) { throw 'Pass -CodexPath with a native codex.exe or add codex to PATH.' }
    $arguments += @('--codex', $CodexPath)
}
& $python @arguments
exit $LASTEXITCODE
