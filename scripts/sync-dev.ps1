# Universal bidirectional sync for the dev branch.
# Compatible with Windows PowerShell 5.1: this file intentionally uses ASCII only.
$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$GitArgs,
        [switch]$AllowFailure
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -C $script:Repo @GitArgs 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if (-not $AllowFailure -and $code -ne 0) {
        $text = ($output | Out-String).Trim()
        throw "Git failed: git $($GitArgs -join ' '). $text"
    }

    return [pscustomobject]@{
        Code = $code
        Output = $output
    }
}

function Get-Text {
    param([object]$Value)
    return (($Value | Out-String).Trim())
}


function Invoke-QuizAiHotReload {
    $flutterCommand = Get-Command flutter.bat -ErrorAction SilentlyContinue
    $flutter = if ($flutterCommand) {
        $flutterCommand.Source
    }
    else {
        Join-Path $env:USERPROFILE 'development\flutter\bin\flutter.bat'
    }

    $adbCommand = Get-Command adb.exe -ErrorAction SilentlyContinue
    $adb = if ($adbCommand) {
        $adbCommand.Source
    }
    else {
        Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    }

    if (-not (Test-Path -LiteralPath $flutter) -or
        -not (Test-Path -LiteralPath $adb)) {
        Write-Host '6/6 Hot reload skipped: Flutter or ADB is not available.'
        return
    }

    $devices = @(
        & $adb devices 2>$null |
            Where-Object { $_ -match '^emulator-\d+\s+device\s*
function Stage-SyncContent {
    Invoke-Git -GitArgs @('add', '-A') | Out-Null

    $experimentsRoot = Join-Path $script:Repo '.ai-apps'
    if (Test-Path -LiteralPath $experimentsRoot) {
        Get-ChildItem -LiteralPath $experimentsRoot -Directory -Filter 'experimentos-*' |
            ForEach-Object {
                $relative = ".ai-apps/$($_.Name)"
                Invoke-Git -GitArgs @('add', '-f', '-A', '--', $relative) | Out-Null
            }
    }
}

function Commit-StagedChanges {
    $staged = Get-Text (Invoke-Git -GitArgs @(
        'diff', '--cached', '--name-only'
    )).Output

    if ([string]::IsNullOrWhiteSpace($staged)) {
        return $false
    }

    $repoName = Split-Path $script:Repo -Leaf
    Invoke-Git -GitArgs @(
        'commit', '-m', "Sync $repoName"
    ) | Out-Null

    return $true
}

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is not available in PATH.'
    }

    $repoResult = & git -C $PSScriptRoot rev-parse --show-toplevel 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot locate the Git repository root. $($repoResult | Out-String)"
    }

    $script:Repo = ($repoResult | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($script:Repo)) {
        throw 'Cannot locate the Git repository root.'
    }

    $branch = Get-Text (Invoke-Git -GitArgs @(
        'symbolic-ref', '--quiet', '--short', 'HEAD'
    )).Output

    if ($branch -ne 'dev') {
        throw "Current branch is '$branch'. This script only syncs dev."
    }

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Write-Host "SYNC DEV - attempt $attempt/3" -ForegroundColor Cyan

        Write-Host '1/5 Staging local changes...'
        Stage-SyncContent

        if (Commit-StagedChanges) {
            Write-Host '    Local commit created.'
        }
        else {
            Write-Host '    No new local changes.'
        }

        Write-Host '2/5 Fetching origin/dev...'
        Invoke-Git -GitArgs @(
            'fetch', '--no-tags', 'origin', 'dev'
        ) | Out-Null

        Write-Host '3/5 Rebasing onto origin/dev...'
        $rebase = Invoke-Git -GitArgs @(
            'rebase', 'refs/remotes/origin/dev'
        ) -AllowFailure

        if ($rebase.Code -ne 0) {
            Invoke-Git -GitArgs @(
                'rebase', '--abort'
            ) -AllowFailure | Out-Null

            throw 'Rebase conflict. Rebase was aborted and nothing was pushed.'
        }

        Write-Host '4/5 Pushing dev...'
        $push = Invoke-Git -GitArgs @(
            'push', 'origin', 'dev'
        ) -AllowFailure

        if ($push.Code -ne 0) {
            $pushText = Get-Text $push.Output

            if (
                $attempt -lt 3 -and
                $pushText -match 'rejected|fetch first|non-fast-forward'
            ) {
                Write-Host '    Remote changed during push. Retrying...' -ForegroundColor Yellow
                continue
            }

            throw "Push failed. $pushText"
        }

        Write-Host '5/5 Verifying local and remote...'
        Invoke-Git -GitArgs @(
            'fetch', '--no-tags', 'origin', 'dev'
        ) | Out-Null

        $local = Get-Text (Invoke-Git -GitArgs @(
            'rev-parse', 'HEAD'
        )).Output

        $remote = Get-Text (Invoke-Git -GitArgs @(
            'rev-parse', 'refs/remotes/origin/dev'
        )).Output

        Stage-SyncContent
        $newStaged = Get-Text (Invoke-Git -GitArgs @(
            'diff', '--cached', '--name-only'
        )).Output

        if (
            $local -eq $remote -and
            [string]::IsNullOrWhiteSpace($newStaged)
        ) {
            Write-Host "SYNC COMPLETE - dev = origin/dev ($($local.Substring(0, 7)))" -ForegroundColor Green
            Invoke-QuizAiHotReload
            exit 0
        }

        if ($attempt -lt 3) {
            if (-not [string]::IsNullOrWhiteSpace($newStaged)) {
                Write-Host '    New local changes appeared. Retrying...' -ForegroundColor Yellow
            }
            else {
                Write-Host '    Remote changed during verification. Retrying...' -ForegroundColor Yellow
            }
            continue
        }

        throw 'Could not stabilize dev after three attempts.'
    }

    throw 'Sync did not complete.'
}
catch {
    Write-Error ("SYNC DEV: " + $_.Exception.Message)
    exit 1
}
 } |
            ForEach-Object { ($_ -split '\s+')[0] }
    )

    if ($devices.Count -ne 1) {
        Write-Host '6/6 Hot reload skipped: no unique Android emulator is connected.'
        return
    }

    $device = $devices[0]
    $appPid = (& $adb -s $device shell pidof com.example.quizai 2>$null |
        Out-String).Trim()

    if ([string]::IsNullOrWhiteSpace($appPid)) {
        Write-Host '6/6 Hot reload skipped: QuizAI is not running.'
        return
    }

    Write-Host '6/6 Hot reloading QuizAI...' -ForegroundColor Cyan

    $quizAi = Join-Path $script:Repo 'apps\quizai'
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $flutter
    $startInfo.Arguments = "attach -d $device"
    $startInfo.WorkingDirectory = $quizAi
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    try {
        if (-not $process.Start()) {
            Write-Host '    Hot reload skipped: flutter attach could not start.' -ForegroundColor Yellow
            return
        }

        Start-Sleep -Milliseconds 2200

        if ($process.HasExited) {
            Write-Host '    Hot reload skipped: no attachable Flutter session was found.' -ForegroundColor Yellow
            return
        }

        $process.StandardInput.WriteLine('r')
        $process.StandardInput.Flush()
        Start-Sleep -Milliseconds 1400

        if (-not $process.HasExited) {
            $process.StandardInput.WriteLine('d')
            $process.StandardInput.Flush()
        }

        if (-not $process.WaitForExit(5000)) {
            $process.Kill()
            $process.WaitForExit()
        }

        Write-Host '    Hot reload requested.' -ForegroundColor Green
    }
    catch {
        Write-Host ("    Hot reload skipped: " + $_.Exception.Message) -ForegroundColor Yellow
        if (-not $process.HasExited) {
            $process.Kill()
        }
    }
    finally {
        $process.Dispose()
    }
}

function Stage-SyncContent {
    Invoke-Git -GitArgs @('add', '-A') | Out-Null

    $experimentsRoot = Join-Path $script:Repo '.ai-apps'
    if (Test-Path -LiteralPath $experimentsRoot) {
        Get-ChildItem -LiteralPath $experimentsRoot -Directory -Filter 'experimentos-*' |
            ForEach-Object {
                $relative = ".ai-apps/$($_.Name)"
                Invoke-Git -GitArgs @('add', '-f', '-A', '--', $relative) | Out-Null
            }
    }
}

function Commit-StagedChanges {
    $staged = Get-Text (Invoke-Git -GitArgs @(
        'diff', '--cached', '--name-only'
    )).Output

    if ([string]::IsNullOrWhiteSpace($staged)) {
        return $false
    }

    $repoName = Split-Path $script:Repo -Leaf
    Invoke-Git -GitArgs @(
        'commit', '-m', "Sync $repoName"
    ) | Out-Null

    return $true
}

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is not available in PATH.'
    }

    $repoResult = & git -C $PSScriptRoot rev-parse --show-toplevel 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot locate the Git repository root. $($repoResult | Out-String)"
    }

    $script:Repo = ($repoResult | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($script:Repo)) {
        throw 'Cannot locate the Git repository root.'
    }

    $branch = Get-Text (Invoke-Git -GitArgs @(
        'symbolic-ref', '--quiet', '--short', 'HEAD'
    )).Output

    if ($branch -ne 'dev') {
        throw "Current branch is '$branch'. This script only syncs dev."
    }

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Write-Host "SYNC DEV - attempt $attempt/3" -ForegroundColor Cyan

        Write-Host '1/5 Staging local changes...'
        Stage-SyncContent

        if (Commit-StagedChanges) {
            Write-Host '    Local commit created.'
        }
        else {
            Write-Host '    No new local changes.'
        }

        Write-Host '2/5 Fetching origin/dev...'
        Invoke-Git -GitArgs @(
            'fetch', '--no-tags', 'origin', 'dev'
        ) | Out-Null

        Write-Host '3/5 Rebasing onto origin/dev...'
        $rebase = Invoke-Git -GitArgs @(
            'rebase', 'refs/remotes/origin/dev'
        ) -AllowFailure

        if ($rebase.Code -ne 0) {
            Invoke-Git -GitArgs @(
                'rebase', '--abort'
            ) -AllowFailure | Out-Null

            throw 'Rebase conflict. Rebase was aborted and nothing was pushed.'
        }

        Write-Host '4/5 Pushing dev...'
        $push = Invoke-Git -GitArgs @(
            'push', 'origin', 'dev'
        ) -AllowFailure

        if ($push.Code -ne 0) {
            $pushText = Get-Text $push.Output

            if (
                $attempt -lt 3 -and
                $pushText -match 'rejected|fetch first|non-fast-forward'
            ) {
                Write-Host '    Remote changed during push. Retrying...' -ForegroundColor Yellow
                continue
            }

            throw "Push failed. $pushText"
        }

        Write-Host '5/5 Verifying local and remote...'
        Invoke-Git -GitArgs @(
            'fetch', '--no-tags', 'origin', 'dev'
        ) | Out-Null

        $local = Get-Text (Invoke-Git -GitArgs @(
            'rev-parse', 'HEAD'
        )).Output

        $remote = Get-Text (Invoke-Git -GitArgs @(
            'rev-parse', 'refs/remotes/origin/dev'
        )).Output

        Stage-SyncContent
        $newStaged = Get-Text (Invoke-Git -GitArgs @(
            'diff', '--cached', '--name-only'
        )).Output

        if (
            $local -eq $remote -and
            [string]::IsNullOrWhiteSpace($newStaged)
        ) {
            Write-Host "SYNC COMPLETE - dev = origin/dev ($($local.Substring(0, 7)))" -ForegroundColor Green
            exit 0
        }

        if ($attempt -lt 3) {
            if (-not [string]::IsNullOrWhiteSpace($newStaged)) {
                Write-Host '    New local changes appeared. Retrying...' -ForegroundColor Yellow
            }
            else {
                Write-Host '    Remote changed during verification. Retrying...' -ForegroundColor Yellow
            }
            continue
        }

        throw 'Could not stabilize dev after three attempts.'
    }

    throw 'Sync did not complete.'
}
catch {
    Write-Error ("SYNC DEV: " + $_.Exception.Message)
    exit 1
}
