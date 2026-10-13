$ErrorActionPreference = 'Stop'
$code = Get-Command code -ErrorAction Stop
$runtime = [IO.Path]::GetFullPath((Join-Path (Split-Path $code.Source -Parent) '../Code.exe'))
$previous = $env:ELECTRON_RUN_AS_NODE
$testDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../.ai-apps/android-tests'))
New-Item -ItemType Directory -Force -Path $testDirectory | Out-Null
Push-Location $testDirectory
try {
    $env:ELECTRON_RUN_AS_NODE = '1'
    & $runtime (Join-Path $PSScriptRoot 'test.cjs') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Android session tests failed.' }
    & $runtime (Join-Path $PSScriptRoot '../embedroid/sessions-test.cjs') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Multi-view tests failed.' }
    & $runtime (Join-Path $PSScriptRoot '../vscode-android/test.cjs') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Editor integration tests failed.' }
    & $runtime (Join-Path $PSScriptRoot 'runner-test.cjs') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Flutter runner regression tests failed.' }
} finally { Pop-Location; $env:ELECTRON_RUN_AS_NODE = $previous }
