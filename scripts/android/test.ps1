$ErrorActionPreference = 'Stop'
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    $runtime = $node.Source
} else {
    $code = Get-Command code -ErrorAction Stop
    $runtime = [IO.Path]::GetFullPath((Join-Path (Split-Path $code.Source -Parent) '../Code.exe'))
    $env:ELECTRON_RUN_AS_NODE = '1'
}
try {
    foreach ($test in @('test.cjs', '../embedroid/sessions-test.cjs', '../vscode-android/test.cjs')) {
        & $runtime (Join-Path $PSScriptRoot $test) | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Fallo: $test" }
    }
} finally {
    if (-not $node) { Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue }
}
