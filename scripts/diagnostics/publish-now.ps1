# Publish one operational snapshot without restarting Android, Flutter or VS Code.
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$branch = (& git -C $repo branch --show-current | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'dev') { throw 'Expected AI-APPS branch dev.' }

$collector = Join-Path $PSScriptRoot 'collect-cli.cjs'
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    $collectorOutput = @(& $node.Source $collector $repo)
    $collectorCode = $LASTEXITCODE
} else {
    $code = Get-Command code -ErrorAction Stop
    $runtime = [IO.Path]::GetFullPath((Join-Path (Split-Path $code.Source -Parent) '../Code.exe'))
    if (-not (Test-Path -LiteralPath $runtime)) { throw 'VS Code Node runtime not found.' }
    $previous = $env:ELECTRON_RUN_AS_NODE
    try {
        $env:ELECTRON_RUN_AS_NODE = '1'
        $collectorOutput = @(& $runtime $collector $repo)
        $collectorCode = $LASTEXITCODE
    } finally { $env:ELECTRON_RUN_AS_NODE = $previous }
}
if ($collectorCode -ne 0) { throw 'Diagnostic collector failed; inspect DIAGNOSTICS_FAILED above.' }
$confirmed = @($collectorOutput | Where-Object { $_ -match '^DIAGNOSTICS_COLLECTED (updated|unchanged)
$file = Join-Path $repo 'diagnostics/current.json'
if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
    throw 'Collector exited without creating diagnostics/current.json; execution was not successful.'
}
Write-Host 'Diagnostic snapshot verified locally. Checking GitHub publication...'

# If the continuous sync owns the lock, allow it to publish; do not race Git
# with a separate push while its background process is active.
$lockPath = Join-Path $repo '.ai-apps/auto-sync-dev.lock'
$running = $false
try {
    $lock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate,
        [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $lock.Dispose()
} catch [IO.IOException] { $running = $true }

if (-not $running) {
    & (Join-Path (Split-Path $PSScriptRoot -Parent) 'sync-dev.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Manual sync did not complete.' }
}

$expected = (& git -C $repo hash-object -- diagnostics/current.json | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot hash local diagnostic snapshot.' }
$deadline = [DateTime]::UtcNow.AddSeconds(55)
do {
    # git show/rev-parse may fail before the first remote publication.
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $remote = (& git -C $repo rev-parse --verify 'refs/remotes/origin/dev:diagnostics/current.json' 2>$null | Out-String).Trim()
        $ok = $LASTEXITCODE -eq 0 -and $remote -eq $expected
    } finally { $ErrorActionPreference = $old }
    if ($ok) {
        Write-Host 'VERIFICADO: diagnostics/current.json sincronizado con origin/dev.' -ForegroundColor Green
        exit 0
    }
    Start-Sleep -Seconds 2
} while ([DateTime]::UtcNow -lt $deadline)

throw 'Snapshot created, but remote publication is not verified. Inspect .ai-apps/auto-sync-dev.log.'
 })
if ($confirmed.Count -ne 1) {
    throw 'Diagnostic collector produced no success confirmation; refusing to publish.'
}
Write-Host $confirmed[0]
$file = Join-Path $repo 'diagnostics/current.json'
if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
    throw 'Collector exited without creating diagnostics/current.json; execution was not successful.'
}
Write-Host 'Diagnostic snapshot verified locally. Checking GitHub publication...'

# If the continuous sync owns the lock, allow it to publish; do not race Git
# with a separate push while its background process is active.
$lockPath = Join-Path $repo '.ai-apps/auto-sync-dev.lock'
$running = $false
try {
    $lock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate,
        [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $lock.Dispose()
} catch [IO.IOException] { $running = $true }

if (-not $running) {
    & (Join-Path (Split-Path $PSScriptRoot -Parent) 'sync-dev.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Manual sync did not complete.' }
}

$expected = (& git -C $repo hash-object -- diagnostics/current.json | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot hash local diagnostic snapshot.' }
$deadline = [DateTime]::UtcNow.AddSeconds(55)
do {
    # git show/rev-parse may fail before the first remote publication.
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $remote = (& git -C $repo rev-parse --verify 'refs/remotes/origin/dev:diagnostics/current.json' 2>$null | Out-String).Trim()
        $ok = $LASTEXITCODE -eq 0 -and $remote -eq $expected
    } finally { $ErrorActionPreference = $old }
    if ($ok) {
        Write-Host 'VERIFICADO: diagnostics/current.json sincronizado con origin/dev.' -ForegroundColor Green
        exit 0
    }
    Start-Sleep -Seconds 2
} while ([DateTime]::UtcNow -lt $deadline)

throw 'Snapshot created, but remote publication is not verified. Inspect .ai-apps/auto-sync-dev.log.'
