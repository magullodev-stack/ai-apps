param(
    [Parameter(Position = 0)]
    [string]$Model = 'gpt-5.6-terra'
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'apps/quizai/run.ps1') -Pivots -PivotModel $Model
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
