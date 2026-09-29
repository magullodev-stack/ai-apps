param(
    [Parameter(Position = 0)]
    [string]$Model = 'gpt-5.6-luna',
    [switch]$Ruta,
    [switch]$Terra,
    [switch]$Sol,
    [switch]$SinU,
    [ValidateRange(1, 100)]
    [int]$Muestras = 1
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'apps/quizai/run.ps1') -Pivots -PivotModel $Model -Ruta:$Ruta -Terra:$Terra -Sol:$Sol -Muestras $Muestras -SinU:$SinU
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
