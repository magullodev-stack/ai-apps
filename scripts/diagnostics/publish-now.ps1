# Publish one diagnostic snapshot without restarting Android, Flutter or VS Code.
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$branch = (& git -C $repo branch --show-current | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'dev') {
    throw 'Expected AI-APPS branch dev.'
}

# The explicit CLI is responsible for creating diagnostics/current.json.
$collector = Join-Path $PSScriptRoot 'collect-cli.cjs'
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    $collectorOutput = @(& $node.Source $collector $repo)
    $collectorCode = $LASTEXITCODE
} else {
    $code = Get-Command code -ErrorAction Stop
    $runtime = [IO.Path]::GetFullPath((Join-Path (Split-Path $code.Source -Parent) '../Code.exe'))
    if (-not (Test-Path -LiteralPath $runtime -PathType Leaf)) {
        throw 'VS Code Node runtime not found.'
    }
    $previous = $env:ELECTRON_RUN_AS_NODE
    try {
        $env:ELECTRON_RUN_AS_NODE = '1'
        $collectorOutput = @(& $runtime $collector $repo)
        $collectorCode = $LASTEXITCODE
    } finally {
        $env:ELECTRON_RUN_AS_NODE = $previous
    }
}
if ($collectorCode -ne 0) {
    throw 'Diagnostic collector failed. See the DIAGNOSTICS_FAILED message above.'
}
# GUI-hosted Node may not forward stdout. Verify the snapshot directly.

$file = Join-Path $repo 'diagnostics/current.json'
if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
    throw 'Diagnostic snapshot was not created.'
}
$report = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
if ($report.schema -ne 1 -or $null -eq $report.gradle -or
    $null -eq $report.development -or $null -eq $report.synchronization) {
    throw 'Diagnostic snapshot has an invalid schema.'
}
$hour = [DateTime]::UtcNow
$acceptableHours = @(
    $hour.ToString('yyyy-MM-ddTHH:00Z'),
    $hour.AddHours(-1).ToString('yyyy-MM-ddTHH:00Z')
)
if ([string]$report.checkedUtcHour -notin $acceptableHours) {
    throw 'Diagnostic snapshot is outdated or was not regenerated.'
}
Write-Host 'Diagnostic snapshot verified locally. Checking GitHub publication...'

# Never race with the existing background Git synchronizer.
$lockPath = Join-Path $repo '.ai-apps/auto-sync-dev.lock'
$running = $false
try {
    $lock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate,
        [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $lock.Dispose()
} catch [IO.IOException] {
    $running = $true
}

if (-not $running) {
    & (Join-Path (Split-Path $PSScriptRoot -Parent) 'sync-dev.ps1')
    if ($LASTEXITCODE -ne 0) {
        throw 'Manual sync did not complete.'
    }
}

$expected = (& git -C $repo hash-object -- diagnostics/current.json | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $expected) {
    throw 'Cannot hash the local diagnostic snapshot.'
}
$deadline = [DateTime]::UtcNow.AddSeconds(55)
$published = $false
do {
    # Read the tracking ref updated by auto-sync-dev.ps1 or sync-dev.ps1.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $remote = (& git -C $repo rev-parse --verify 'refs/remotes/origin/dev:diagnostics/current.json' 2>$null | Out-String).Trim()
        $published = ($LASTEXITCODE -eq 0 -and $remote -eq $expected)
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($published) {
        Write-Host 'VERIFICADO: diagnostics/current.json sincronizado con origin/dev.' -ForegroundColor Green
        exit 0
    }
    Start-Sleep -Seconds 2
} while ([DateTime]::UtcNow -lt $deadline)
throw 'Snapshot created but remote publication was not verified. Inspect .ai-apps/auto-sync-dev.log.'
