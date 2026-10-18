param([string]$Device)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'build.ps1') | Out-Null
$tests = @('sessions-test.cjs', 'test.cjs')
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    foreach ($test in $tests) {
        $arguments = @((Join-Path $PSScriptRoot $test))
        if ($test -eq 'test.cjs' -and $Device) { $arguments += @('--device', $Device) }
        & $node.Source @arguments
        if ($LASTEXITCODE -ne 0) { throw "Fallo test EmbeDroid: $test" }
    }
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
        foreach ($test in $tests) {
            $arguments = @((Join-Path $PSScriptRoot $test))
            if ($test -eq 'test.cjs' -and $Device) { $arguments += @('--device', $Device) }
            & $runtime @arguments | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "Fallo test EmbeDroid: $test" }
        }
    }
    finally { Pop-Location; $env:ELECTRON_RUN_AS_NODE = $previous }
}
if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas del transporte EmbeDroid.' }
