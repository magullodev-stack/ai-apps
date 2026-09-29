param(
    [Parameter(Position = 0)]
    [string]$Model = 'gpt-5.6-luna',
    [ValidateRange(1, 30)]
    [int]$Muestras = 30
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'apps/quizai/run.ps1') -EvaluarDimensiones -CatalogModel $Model -DimensionesMuestras $Muestras
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
