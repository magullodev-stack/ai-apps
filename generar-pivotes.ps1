param(
    [Parameter(Position = 0)]
    [string]$Model = 'gpt-5.6-luna',
    [switch]$Ruta,
    [switch]$Terra,
    [switch]$Sol
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'apps/quizai/run.ps1') -Pivots -PivotModel $Model -Ruta:$Ruta -Terra:$Terra -Sol:$Sol
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
