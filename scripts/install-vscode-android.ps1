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

function Remove-AndroidExtensionDirectory([string]$Directory) {
    $absolute = [IO.Path]::GetFullPath($Directory)
    $root = [IO.Path]::GetFullPath($extensionsRoot).TrimEnd('\')
    if ((Split-Path $absolute -Parent) -ine $root -or
        (Split-Path $absolute -Leaf) -notlike "$($manifest.publisher).$($manifest.name)-*") {
        throw 'Ruta de extension fuera del directorio esperado.'
    }
    $item = Get-Item -LiteralPath $absolute -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        # Remove the junction itself, never the repository behind it.
        [IO.Directory]::Delete($absolute)
    } else { Remove-Item -LiteralPath $absolute -Recurse -Force }
}

Get-ChildItem -LiteralPath $extensionsRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -like "$($manifest.publisher).$($manifest.name)-*" -and
        $_.FullName -ne $target
    } |
    ForEach-Object { Remove-AndroidExtensionDirectory $_.FullName }

$alreadyLinked = $false

if (Test-Path -LiteralPath $target) {
    $item = Get-Item -LiteralPath $target -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        try {
            $resolvedTarget = (Get-Item -LiteralPath $target -Force).Target
            if ($resolvedTarget -is [array]) {
                $resolvedTarget = $resolvedTarget[0]
            }

            if ($resolvedTarget) {
                $resolvedTarget = [IO.Path]::GetFullPath(
                    (Join-Path (Split-Path $target -Parent) $resolvedTarget)
                )
                $sourceFull = [IO.Path]::GetFullPath($source)

                if ($resolvedTarget.TrimEnd('\') -ieq $sourceFull.TrimEnd('\')) {
                    $alreadyLinked = $true
                }
            }
        }
        catch {
            $alreadyLinked = $false
        }
    }

    if (-not $alreadyLinked) {
        Remove-AndroidExtensionDirectory $target
    }
}

if (-not $alreadyLinked) {
    try {
        New-Item -ItemType Junction -Path $target -Target $source | Out-Null
        Write-Host "Extensión AI-APPS Android enlazada al repo: $target" -ForegroundColor Green
    }
    catch {
        Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
        Write-Warning 'No se pudo crear el enlace de desarrollo; se instaló una copia.'
    }
}
else {
    Write-Host 'Extensión AI-APPS Android ya enlazada al repo.'
}

Write-Host 'Reinicia o recarga VS Code para cargar cambios del código de la extensión.'
