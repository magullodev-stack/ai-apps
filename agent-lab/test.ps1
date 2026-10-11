param()
$ErrorActionPreference = 'Stop'
$python = Join-Path $PSScriptRoot '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw 'Run agent-lab/install.ps1 first.' }
& $python -B -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -v
exit $LASTEXITCODE
