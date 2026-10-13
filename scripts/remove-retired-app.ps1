# Remove a retired app's local working tree and Android package.
# Does not preserve backup copies, reset the emulator, or touch the current app.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string]$App,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z][\\w]*(?:\\.[A-Za-z][\\w]*)+$')]
    [string]$Package,
    [switch]$SkipEditorInstall
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = Split-Path $PSScriptRoot -Parent
if ($App -eq 'muondia' -or $Package -eq 'com.aiapps.muondia') {
    throw 'Refusing to remove Muondia.'
}
$root = (& git -C $repo rev-parse --show-toplevel | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $root.TrimEnd('\\') -ine $repo.TrimEnd('\\')) {
    throw 'This command must run from the AI-APPS repository.'
}
$branch = (& git -C $repo branch --show-current | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'dev') { throw 'Expected branch dev.' }
if (-not (Test-Path -LiteralPath (Join-Path $repo 'apps/muondia/pubspec.yaml'))) {
    throw 'Muondia was not found; refusing to remove anything.'
}

# Never follow a junction/symlink while deleting a retired directory.
$retired = Join-Path (Join-Path $repo 'apps') $App
if (Test-Path -LiteralPath $retired) {
    $item = Get-Item -LiteralPath $retired -Force
    if (-not $item.PSIsContainer -or
        ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'The retired app path is not an ordinary directory. No files deleted.'
    }
    Remove-Item -LiteralPath $retired -Recurse -Force -ErrorAction Stop
    if (Test-Path -LiteralPath $retired) {
        throw 'The retired directory is still present after deletion.'
    }
    Write-Host "ELIMINADO: apps/$App/ (sin copia de seguridad)." -ForegroundColor Green
} else {
    Write-Host "VERIFICADO: apps/$App/ no existe."
}

# Remove the obsolete ignore rule only AFTER deleting the ignored directory.
$ignoreFile = Join-Path $repo '.gitignore'
$ignore = [IO.File]::ReadAllText($ignoreFile, [Text.Encoding]::UTF8)
$rule = '/apps/' + $App + '/'
$escaped = [regex]::Escape($rule)
$revised = [regex]::Replace($ignore, "(?m)^$escaped\\r?\\n", '')
$revised = [regex]::Replace($revised,
    '(?m)^# Muondia replaced the previous application directory\\.\\r?\\n# Never re-import generated leftovers from the old local Flutter tree\\.\\r?\\n', '')
if ($revised -ne $ignore) {
    [IO.File]::WriteAllText($ignoreFile, $revised, (New-Object Text.UTF8Encoding($false)))
    Write-Host 'ELIMINADO: regla antigua de .gitignore.' -ForegroundColor Green
}

# Only exact Android package names are ever uninstalled. Preserve Android,
# its snapshots, all other packages and every running development process.
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
} else { Join-Path $env:LOCALAPPDATA 'Android/Sdk' }
$adb = Join-Path $sdk 'platform-tools/adb.exe'
$allVerified = $true
if (Test-Path -LiteralPath $adb) {
    $devices = @(& $adb devices | Where-Object { $_ -match '^(emulator-[0-9]+)\\s+device\\s*$' } |
        ForEach-Object { ($_ -split '\\s+')[0] })
    if ($LASTEXITCODE -ne 0) { throw 'ADB could not list Android devices.' }
    if ($devices.Count -eq 0) {
        Write-Warning 'No emulator is online: the old Android package cannot yet be verified.'
        $allVerified = $false
    }
    foreach ($serial in $devices) {
        $packages = @(& $adb -s $serial shell pm list packages --user 0 $Package)
        if ($LASTEXITCODE -ne 0) { throw "Cannot inspect package on $serial." }
        if ($packages -contains "package:$Package") {
            & $adb -s $serial uninstall $Package | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "Failed to uninstall $Package on $serial." }
            Write-Host "DESINSTALADO: $Package en $serial." -ForegroundColor Green
        }
        $remaining = @(& $adb -s $serial shell pm list packages --user 0 $Package)
        if ($LASTEXITCODE -ne 0 -or $remaining -contains "package:$Package") {
            throw "Old Android package still detected on $serial."
        }
        Write-Host "VERIFICADO: $serial sin $Package."
    }
} else {
    Write-Warning 'ADB missing; Android package verification remains pending.'
    $allVerified = $false
}

# The maintained extension restores the authoritative current session identity.
# Install it only after the working tree cleanup. Reload VS Code afterwards.
if (-not $SkipEditorInstall) {
    & (Join-Path $PSScriptRoot 'install-embedroid.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'EmbeDroid installation failed.' }
    Write-Host 'Extensiones actualizadas. Recarga VS Code para aplicar la restauracion corregida.'
}

# Inspect tracked text for further references. Git history is intentionally left intact.
$remainingRefs = @(& git -C $repo grep -in -- $App 2>$null)
if ($LASTEXITCODE -gt 1) { throw 'git grep failed.' }
if ($remainingRefs.Count -gt 0) {
    Write-Warning "Referencias restantes en archivos versionados:"
    $remainingRefs | ForEach-Object { Write-Host $_ }
    $allVerified = $false
}
if ($allVerified) {
    Write-Host "VERIFICADO: sin carpeta apps/$App, sin regla de exclusion y sin paquete en los emuladores conectados." -ForegroundColor Green
} else {
    Write-Warning 'Limpieza local realizada; quedan comprobaciones indicadas arriba.'
}
