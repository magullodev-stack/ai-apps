$ErrorActionPreference = 'Stop'
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
