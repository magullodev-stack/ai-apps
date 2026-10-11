param(
    [Parameter(Mandatory = $true)][ValidateSet('Start','Status','Stop','Detach')][string]$Action,
    [Parameter(Mandatory = $true)][string]$Run,
    [string]$Project,
    [string]$Serial,
    [string]$Avd
)
$ErrorActionPreference = 'Stop'
$python = Join-Path $PSScriptRoot '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw 'Run agent-lab/install.ps1 first.' }
$arguments = @('-B', (Join-Path $PSScriptRoot 'lab_android.py'), '--action', $Action.ToLowerInvariant(),
    '--run', (Resolve-Path -LiteralPath $Run).Path)
if ($Project) { $arguments += @('--project', $Project) }
if ($Serial) { $arguments += @('--serial', $Serial) }
if ($Avd) { $arguments += @('--avd', $Avd) }
& $python @arguments
exit $LASTEXITCODE
