param(
    [Parameter(Position = 0)]
    [string]$Model = 'gpt-5.6-luna',
    [switch]$Ruta,
    [switch]$Terra,
    [switch]$Sol,
    [switch]$SinU,
    [switch]$ExcluirTop3,
    [switch]$ExcluirTop6,
    [ValidateRange(1, 200)]
    [int]$Muestras = 1
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'apps/quizai/run.ps1') -Pivots -PivotModel $Model -Ruta:$Ruta -Terra:$Terra -Sol:$Sol -Muestras $Muestras -SinU:$SinU -ExcluirTop3:$ExcluirTop3 -ExcluirTop6:$ExcluirTop6
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
