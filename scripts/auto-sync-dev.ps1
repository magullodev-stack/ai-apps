param(
    [ValidateRange(1, 60)]
    [int]$RemotePollSeconds = 8,
    [ValidateRange(1, 60)]
    [int]$LocalIdleSeconds = 6
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$GitArgs,
        [switch]$AllowFailure
    )

    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -C $script:Repo @GitArgs 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $old
    }

    if (-not $AllowFailure -and $code -ne 0) {
        $text = (($output | Out-String).Trim())
        throw "Git failed: git $($GitArgs -join ' '). $text"
    }

    return [pscustomobject]@{
        Code = $code
        Output = $output
    }
}

function Get-Text([object]$Value) {
    return (($Value | Out-String).Trim())
}

function Write-Log([string]$Message) {
    $line = "[{0}] {1}" -f ([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')), $Message
    Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8
}

# Publish a bounded, sanitized snapshot through the existing dev sync.
function Export-Diagnostics {
    $collector = Join-Path $script:Repo 'scripts/diagnostics/collect.cjs'
    if (-not (Test-Path -LiteralPath $collector)) { return }

    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node) {
        & $node.Source $collector $script:Repo 2>$null | Out-Null
    } else {
        # VS Code embeds Node; no extra Node installation is necessary.
        $code = Get-Command code -ErrorAction SilentlyContinue
        if (-not $code) { throw 'Diagnostics runtime unavailable.' }
        $runtime = [IO.Path]::GetFullPath((Join-Path (Split-Path $code.Source -Parent) '../Code.exe'))
        if (-not (Test-Path -LiteralPath $runtime)) { throw 'Diagnostics runtime unavailable.' }
        $previous = $env:ELECTRON_RUN_AS_NODE
        try {
            $env:ELECTRON_RUN_AS_NODE = '1'
            & $runtime $collector $script:Repo 2>$null | Out-Null
        }
        finally { $env:ELECTRON_RUN_AS_NODE = $previous }
    }
    if ($LASTEXITCODE -ne 0) { throw 'Diagnostics exporter failed.' }
}

function Test-GitOperationInProgress {
    $gitDir = Get-Text (Invoke-Git -GitArgs @('rev-parse', '--git-dir')).Output
    if (-not [IO.Path]::IsPathRooted($gitDir)) {
        $gitDir = Join-Path $script:Repo $gitDir
    }

    foreach ($name in @(
        'rebase-merge',
        'rebase-apply',
        'MERGE_HEAD',
        'CHERRY_PICK_HEAD',
        'REVERT_HEAD'
    )) {
        if (Test-Path -LiteralPath (Join-Path $gitDir $name)) {
            return $true
        }
    }

    return $false
}

function Get-WorkingState {
    $status = Get-Text (Invoke-Git -GitArgs @(
        'status', '--porcelain=v1', '-uall'
    )).Output

    if ([string]::IsNullOrWhiteSpace($status)) {
        return [pscustomobject]@{
            Dirty = $false
            Fingerprint = ''
        }
    }

    $separator = [Environment]::NewLine + '---' + [Environment]::NewLine
    $parts = @(
        $status,
        (Get-Text (Invoke-Git -GitArgs @(
            'diff', '--no-ext-diff', '--binary'
        )).Output),
        (Get-Text (Invoke-Git -GitArgs @(
            'diff', '--cached', '--no-ext-diff', '--binary'
        )).Output)
    ) -join $separator

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($parts)
        $hash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }

    return [pscustomobject]@{
        Dirty = $true
        Fingerprint = $hash
    }
}

function Commit-LocalChanges {
    Invoke-Git -GitArgs @('add', '-A') | Out-Null

    $staged = Get-Text (Invoke-Git -GitArgs @(
        'diff', '--cached', '--name-only'
    )).Output

    if ([string]::IsNullOrWhiteSpace($staged)) {
        return $false
    }

    Invoke-Git -GitArgs @(
        'commit', '-m', 'Auto-sync ai-apps'
    ) | Out-Null

    Write-Log 'Local changes committed automatically.'
    return $true
}

function Sync-Remote {
    $fetch = Invoke-Git -GitArgs @(
        'fetch', '--no-tags', 'origin', 'dev'
    ) -AllowFailure

    if ($fetch.Code -ne 0) {
        Write-Log ("Fetch failed: " + (Get-Text $fetch.Output))
        return
    }

    $local = Get-Text (Invoke-Git -GitArgs @('rev-parse', 'HEAD')).Output
    $remote = Get-Text (Invoke-Git -GitArgs @(
        'rev-parse', 'refs/remotes/origin/dev'
    )).Output

    if ($local -eq $remote) {
        return
    }

    $localBehind = Invoke-Git -GitArgs @(
        'merge-base', '--is-ancestor', $local, $remote
    ) -AllowFailure

    if ($localBehind.Code -eq 0) {
        $merge = Invoke-Git -GitArgs @(
            'merge', '--ff-only', 'refs/remotes/origin/dev'
        ) -AllowFailure

        if ($merge.Code -eq 0) {
            Write-Log "Remote changes applied automatically: $($remote.Substring(0, 7))."
        }
        else {
            Write-Log ("Fast-forward failed: " + (Get-Text $merge.Output))
        }
        return
    }

    $remoteBehind = Invoke-Git -GitArgs @(
        'merge-base', '--is-ancestor', $remote, $local
    ) -AllowFailure

    if ($remoteBehind.Code -eq 0) {
        $push = Invoke-Git -GitArgs @(
            'push', 'origin', 'dev'
        ) -AllowFailure

        if ($push.Code -eq 0) {
            Write-Log "Local changes pushed automatically: $($local.Substring(0, 7))."
        }
        else {
            Write-Log ("Push failed: " + (Get-Text $push.Output))
        }
        return
    }

    $rebase = Invoke-Git -GitArgs @(
        'rebase', 'refs/remotes/origin/dev'
    ) -AllowFailure

    if ($rebase.Code -ne 0) {
        Invoke-Git -GitArgs @('rebase', '--abort') -AllowFailure | Out-Null
        Write-Log 'Automatic sync paused for this cycle because dev diverged and rebase conflicted.'
        return
    }

    $newLocal = Get-Text (Invoke-Git -GitArgs @('rev-parse', 'HEAD')).Output
    $pushAfterRebase = Invoke-Git -GitArgs @(
        'push', 'origin', 'dev'
    ) -AllowFailure

    if ($pushAfterRebase.Code -eq 0) {
        Write-Log "Diverged dev rebased and pushed automatically: $($newLocal.Substring(0, 7))."
    }
    else {
        Write-Log ("Push after rebase failed: " + (Get-Text $pushAfterRebase.Output))
    }
}

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        exit 0
    }

    $repoResult = & git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) {
        exit 0
    }

    $script:Repo = (($repoResult | Out-String).Trim())
    if ([string]::IsNullOrWhiteSpace($script:Repo)) {
        exit 0
    }

    $runtime = Join-Path $script:Repo '.ai-apps'
    New-Item -ItemType Directory -Force -Path $runtime | Out-Null

    $script:LogFile = Join-Path $runtime 'auto-sync-dev.log'
    $lockPath = Join-Path $runtime 'auto-sync-dev.lock'

    try {
        $lock = [IO.File]::Open(
            $lockPath,
            [IO.FileMode]::OpenOrCreate,
            [IO.FileAccess]::ReadWrite,
            [IO.FileShare]::None
        )
    }
    catch {
        exit 0
    }

    try {
        $lock.SetLength(0)
        $writer = New-Object IO.StreamWriter($lock, [Text.Encoding]::UTF8, 1024, $true)
        try {
            $writer.Write("$PID")
            $writer.Flush()
        }
        finally {
            $writer.Dispose()
        }

        $branch = Get-Text (Invoke-Git -GitArgs @(
            'symbolic-ref', '--quiet', '--short', 'HEAD'
        )).Output

        if ($branch -ne 'dev') {
            Write-Log "Auto-sync not started because current branch is '$branch'."
            exit 0
        }

        Write-Log 'Continuous dev sync started.'

        $lastFingerprint = $null
        $dirtySince = $null
        $nextRemoteCheck = [DateTime]::UtcNow

        $nextDiagnosticsCheck = [DateTime]::UtcNow
        $diagnosticsFailed = $false

        while ($true) {
            if ([DateTime]::UtcNow -ge $nextDiagnosticsCheck) {
                try {
                    Export-Diagnostics
                    $diagnosticsFailed = $false
                }
                catch {
                    # Never include exception text in logs: it might expose paths.
                    if (-not $diagnosticsFailed) { Write-Log 'Diagnostics exporter unavailable.' }
                    $diagnosticsFailed = $true
                }
                $nextDiagnosticsCheck = [DateTime]::UtcNow.AddMinutes(1)
            }
            if (Test-GitOperationInProgress) {
                Start-Sleep -Seconds 1
                continue
            }

            $state = Get-WorkingState

            if ($state.Dirty) {
                if ($state.Fingerprint -ne $lastFingerprint) {
                    $lastFingerprint = $state.Fingerprint
                    $dirtySince = [DateTime]::UtcNow
                }
                elseif ($null -ne $dirtySince -and
                    ([DateTime]::UtcNow - $dirtySince).TotalSeconds -ge $LocalIdleSeconds) {
                    try {
                        if (Commit-LocalChanges) {
                            Sync-Remote
                        }
                    }
                    catch {
                        Write-Log ("Local auto-sync failed: " + $_.Exception.Message)
                    }

                    $lastFingerprint = $null
                    $dirtySince = $null
                    $nextRemoteCheck = [DateTime]::UtcNow.AddSeconds($RemotePollSeconds)
                }
            }
            else {
                $lastFingerprint = $null
                $dirtySince = $null

                if ([DateTime]::UtcNow -ge $nextRemoteCheck) {
                    try {
                        Sync-Remote
                    }
                    catch {
                        Write-Log ("Remote auto-sync failed: " + $_.Exception.Message)
                    }

                    $nextRemoteCheck = [DateTime]::UtcNow.AddSeconds($RemotePollSeconds)
                }
            }

            Start-Sleep -Seconds 1
        }
    }
    finally {
        $lock.Dispose()
    }
}
catch {
    if ($script:LogFile) {
        Write-Log ("Auto-sync stopped: " + $_.Exception.Message)
    }
}
