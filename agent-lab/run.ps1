param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Instruction,
    [string]$SourceRepo,
    [string]$CodexPath,
    [string]$Model,
    [ValidateRange(1, 3600)][int]$TimeoutSeconds = 300,
    [switch]$Offline
)
$ErrorActionPreference = 'Stop'
$python = Join-Path $PSScriptRoot '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw 'Run agent-lab/install.ps1 first.' }
$arguments = @('-B', (Join-Path $PSScriptRoot 'lab.py'), '--instruction', $Instruction, '--timeout', "$TimeoutSeconds")
if ($SourceRepo) { $arguments += @('--source', (Resolve-Path -LiteralPath $SourceRepo).Path) }
if ($Model) { $arguments += @('--model', $Model) }
if ($Offline) {
    $arguments += @('--executor', 'fake')
}
else {
    if (-not $CodexPath) {
        $command = Get-Command codex -ErrorAction SilentlyContinue
        if ($command) { $CodexPath = $command.Source }
    }
    if (-not $CodexPath) { throw 'Codex missing. Install Codex CLI or pass -CodexPath with the native codex.exe path.' }
    $arguments += @('--codex', $CodexPath)
}
& $python @arguments
exit $LASTEXITCODE
