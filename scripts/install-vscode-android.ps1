$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot 'vscode-android'
$manifestPath = Join-Path $source 'package.json'

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "No se encuentra el manifiesto de la extensión: $manifestPath"
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$extensionsRoot = Join-Path $env:USERPROFILE '.vscode\extensions'
$targetName = "$($manifest.publisher).$($manifest.name)-$($manifest.version)"
$target = Join-Path $extensionsRoot $targetName

New-Item -ItemType Directory -Force -Path $extensionsRoot | Out-Null

Get-ChildItem -LiteralPath $extensionsRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -like "$($manifest.publisher).$($manifest.name)-*" -and
        $_.FullName -ne $target
    } |
    Remove-Item -Recurse -Force

if (Test-Path -LiteralPath $target) {
    Remove-Item -LiteralPath $target -Recurse -Force
}

Copy-Item -LiteralPath $source -Destination $target -Recurse -Force

Write-Host "Extensión AI-APPS Android instalada en: $target" -ForegroundColor Green
Write-Host 'Reinicia VS Code para cargar la versión nueva.'
