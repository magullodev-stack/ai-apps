param(
    [Parameter(Mandatory = $true)][ValidateSet('List','Register','Start','Stop','Unregister')][string]$Action,
    [string]$AppId, [string]$Label, [string]$Serial, [string]$AvdName,
    [string]$ProjectPath, [string]$PackageName,
    [ValidateSet('flutter','external')][string]$Kind = 'flutter'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$arguments = @((Join-Path $PSScriptRoot 'android/cli.cjs'), $repo, $Action)
if ($Action -eq 'Register') {
    if (-not $Label) { $Label = $AppId }
    $definition = @{ appId=$AppId; label=$Label; serial=$Serial; kind=$Kind; packageName=$PackageName }
    if ($AvdName) { $definition.avdName = $AvdName }
    if ($ProjectPath) { $definition.projectPath = (Resolve-Path -LiteralPath $ProjectPath).Path }
    $registrationJson = (ConvertTo-Json -Compress -InputObject $definition)
} elseif ($Action -in @('Start','Stop','Unregister')) {
    if (-not $AppId -or -not $Serial) { throw 'Specify -AppId and -Serial.' }
    $arguments += "$AppId@$Serial"
}
$node = Get-Command node -ErrorAction SilentlyContinue
$runtimeDirectory = Join-Path $repo '.ai-apps/android'
New-Item -ItemType Directory -Force -Path $runtimeDirectory | Out-Null
Push-Location $runtimeDirectory
$previousOutputEncoding = $OutputEncoding
try {
$OutputEncoding = New-Object Text.UTF8Encoding($false)
if ($node) {
    if ($Action -eq 'Register') { $registrationJson | & $node.Source @arguments }
    else { & $node.Source @arguments }
}
else {
    $code = Get-Command code -ErrorAction Stop
    $runtime = [IO.Path]::GetFullPath((Join-Path (Split-Path $code.Source -Parent) '../Code.exe'))
    $previous = $env:ELECTRON_RUN_AS_NODE
    try {
        $env:ELECTRON_RUN_AS_NODE = '1'
        if ($Action -eq 'Register') { $registrationJson | & $runtime @arguments | Out-Host }
        else { & $runtime @arguments | Out-Host }
    }
    finally { $env:ELECTRON_RUN_AS_NODE = $previous }
}
} finally { $OutputEncoding = $previousOutputEncoding; Pop-Location }
exit $LASTEXITCODE
