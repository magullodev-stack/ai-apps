$ErrorActionPreference = 'Stop'
# Catch truncated or duplicated PowerShell strings before Windows installation.
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
foreach ($scriptFile in @(
    (Join-Path $PSScriptRoot 'publish-now.ps1'),
    (Join-Path $repo 'scripts/auto-sync-dev.ps1')
)) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $scriptFile, [ref]$tokens, [ref]$parseErrors
    ) | Out-Null
    if ($null -ne $parseErrors -and $parseErrors.Count -gt 0) {
        throw ('PowerShell syntax errors in ' + $scriptFile + ': ' + $parseErrors[0].Message)
    }
}
Write-Host 'PASS: PowerShell publisher and synchronizer syntax.'

$test = Join-Path $PSScriptRoot 'collect-test.cjs'
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    & $node.Source $test
} else {
    $code = Get-Command code -ErrorAction Stop
    $runtime = [IO.Path]::GetFullPath((Join-Path (Split-Path $code.Source -Parent) '../Code.exe'))
    if (-not (Test-Path -LiteralPath $runtime)) { throw 'VS Code Node runtime not found.' }
    $previous = $env:ELECTRON_RUN_AS_NODE
    try {
        $env:ELECTRON_RUN_AS_NODE = '1'
        & $runtime $test
    } finally { $env:ELECTRON_RUN_AS_NODE = $previous }
}
if ($LASTEXITCODE -ne 0) { throw 'Diagnostic collector tests failed.' }
