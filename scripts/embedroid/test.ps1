param([string]$Device)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'build.ps1') | Out-Null
$argsForTest = @((Join-Path $PSScriptRoot 'test.cjs'))
if ($Device) { $argsForTest += @('--device', $Device) }
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    & $node.Source @argsForTest
}
else {
    $code = Get-Command code -ErrorAction Stop
    $runtime = [IO.Path]::GetFullPath((Join-Path (Split-Path $code.Source -Parent) '../Code.exe'))
    $previous = $env:ELECTRON_RUN_AS_NODE
    try {
        $env:ELECTRON_RUN_AS_NODE = '1'
        Push-Location (Join-Path $PSScriptRoot '../../.ai-apps/embedroid')
        # Code.exe is a GUI executable; piping makes Windows PowerShell wait
        # for completion and collect its exit code, rather than a stale one.
        & $runtime @argsForTest | Out-Host
    }
    finally { Pop-Location; $env:ELECTRON_RUN_AS_NODE = $previous }
}
if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas del transporte EmbeDroid.' }
