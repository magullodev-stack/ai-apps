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

    # git diff no ve el contenido de ficheros nuevos (untracked).
    # Su hash debe cambiar mientras se estan escribiendo, para no guardar
    # automaticamente un fichero a medio copiar.
    $untracked = Invoke-Git -GitArgs @(
        '-c', 'core.quotepath=false',
        'ls-files', '--others', '--exclude-standard'
    )
    $newFileHashes = @(
        foreach ($path in @($untracked.Output)) {
            $relative = [string]$path
            if ([string]::IsNullOrWhiteSpace($relative)) { continue }
            $fullPath = Join-Path $script:Repo $relative
            try {
                $fileHash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256 -ErrorAction Stop).Hash
                "$relative $fileHash"
            }
            catch {
                # Si se esta creando/borrando durante la lectura, el estado
                # no es estable y no debe desencadenar un commit.
                "$relative INCOMPLETE:$([Guid]::NewGuid().ToString('N'))"
            }
        }
    )

    $separator = [Environment]::NewLine + '---' + [Environment]::NewLine
    $parts = @(
        $status,
        (Get-Text (Invoke-Git -GitArgs @(
            'diff', '--no-ext-diff', '--binary'
        )).Output),
        (Get-Text (Invoke-Git -GitArgs @(
            'diff', '--cached', '--no-ext-diff', '--binary'
        )).Output),
        ($newFileHashes -join [Environment]::NewLine)
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
    param([bool]$WorkingDirty = $false)

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
            $script:DeferredRemote = $null
            Write-Log "Remote changes applied automatically: $($remote.Substring(0, 7))."
        }
        elseif ($WorkingDirty) {
            # Git preserva los cambios locales y rechaza el avance si chocan.
            # Registrar una sola vez por revision; reintentar en el siguiente ciclo.
            if ($script:DeferredRemote -ne $remote) {
                Write-Log "Remote revision $($remote.Substring(0, 7)) waiting: local changes prevent fast-forward."
                $script:DeferredRemote = $remote
            }
        }
        else {
            Write-Log ("Fast-forward failed: " + (Get-Text $merge.Output))
        }
        return
    }

    if ($WorkingDirty) {
        # No hacer rebase ni push automatico de un arbol de trabajo que
        # sigue cambiando. El fetch ya ha recibido la revision remota.
        if ($script:DeferredRemote -ne $remote) {
            Write-Log "Remote revision $($remote.Substring(0, 7)) fetched; waiting for clean local changes."
            $script:DeferredRemote = $remote
        }
        return
    }

    $script:DeferredRemote = $null
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
        $script:DeferredRemote = $null
        $nextRemoteCheck = [DateTime]::UtcNow

        while ($true) {
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
                        # Revalidar justo antes de guardar para no publicar
                        # un fichero que ha vuelto a modificarse.
                        $confirmed = Get-WorkingState
                        if ($confirmed.Dirty -and $confirmed.Fingerprint -eq $state.Fingerprint) {
                            if (Commit-LocalChanges) {
                                Write-Log 'Local worktree stable; checking remote changes.'
                            }
                            $lastFingerprint = $null
                            $dirtySince = $null
                            $nextRemoteCheck = [DateTime]::UtcNow
                        } else {
                            $lastFingerprint = $confirmed.Fingerprint
                            $dirtySince = [DateTime]::UtcNow
                        }
                    }
                    catch {
                        Write-Log ("Local auto-sync failed: " + $_.Exception.Message)
                        $lastFingerprint = $null
                        $dirtySince = $null
                    }
                }
            }
            else {
                $lastFingerprint = $null
                $dirtySince = $null
            }

            # Nunca suspender el fetch solo porque existan cambios locales.
            # Git solo aplica fast-forward si puede conservarlos intactos.
            if ([DateTime]::UtcNow -ge $nextRemoteCheck) {
                try {
                    $workingDirty = (Get-WorkingState).Dirty
                    Sync-Remote -WorkingDirty $workingDirty
                }
                catch {
                    Write-Log ("Remote auto-sync failed: " + $_.Exception.Message)
                }
                $nextRemoteCheck = [DateTime]::UtcNow.AddSeconds($RemotePollSeconds)
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
