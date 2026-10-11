$ErrorActionPreference = 'Stop'

$vsix = & (Join-Path $PSScriptRoot 'embedroid/build.ps1')
& (Join-Path $PSScriptRoot 'embedroid/test.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Las pruebas de EmbeDroid han fallado.' }
& (Join-Path $PSScriptRoot 'android/test.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Las pruebas multiemulador han fallado.' }

& code --install-extension $vsix --force
if ($LASTEXITCODE -ne 0) { throw 'No se pudo instalar EmbeDroid corregido.' }

$installed = & code --list-extensions
if ($LASTEXITCODE -ne 0) { throw 'No se pudo consultar las extensiones instaladas.' }
if ($installed -contains 'utpalbarman.embedroid') {
    & code --uninstall-extension utpalbarman.embedroid
    if ($LASTEXITCODE -ne 0) { throw 'Desinstala EmbeDroid original para evitar comandos duplicados.' }
}

& (Join-Path $PSScriptRoot 'install-vscode-android.ps1')
Write-Host 'EmbeDroid corregido instalado. Recarga VS Code; Android y Flutter continúan activos.'
