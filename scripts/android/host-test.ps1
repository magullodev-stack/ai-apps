param(
    [string]$Workspace = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [string]$AppId = 'lab-validation',
    [string]$Serial = 'emulator-5556',
    [string]$Label = 'Lab validation',
    [ValidatePattern('^[a-z0-9-]+$')][string]$RuntimeName = 'android-host'
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../embedroid/build.ps1') | Out-Null
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$runtime = Join-Path $repo ('.ai-apps/' + $RuntimeName)
New-Item -ItemType Directory -Force -Path $runtime, "$runtime/profile", "$runtime/extensions" | Out-Null
New-Item -ItemType Directory -Force -Path "$runtime/controller" | Out-Null
$controllerManifest = @{ name='android-session-test-controller'; publisher='magullodev'; version='0.0.1';
    engines=@{ vscode='^1.96.0' }; main='./extension.js'; activationEvents=@('onStartupFinished');
    extensionDependencies=@('magullodev.ai-apps-android') }
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText("$runtime/controller/package.json", ($controllerManifest | ConvertTo-Json -Depth 5), $utf8)
[IO.File]::WriteAllText("$runtime/target.json", (@{appId=$AppId; serial=$Serial; label=$Label} | ConvertTo-Json), $utf8)
$options = @{runtime=$runtime} | ConvertTo-Json -Compress
$testModule = (Join-Path $PSScriptRoot 'host-test.cjs') | ConvertTo-Json -Compress
[IO.File]::WriteAllText("$runtime/controller/extension.js", ('exports.activate=()=>require(' + $testModule + ').run(' + $options + ').catch(()=>require("vscode").commands.executeCommand("workbench.action.closeWindow"));'), $utf8)
$code = Get-Command code -ErrorAction Stop
$codeExe = [IO.Path]::GetFullPath((Join-Path (Split-Path $code.Source -Parent) '../Code.exe'))
$previous = $env:ELECTRON_RUN_AS_NODE
try {
    $env:ELECTRON_RUN_AS_NODE = $null
    for ($phase = 1; $phase -le 2; $phase++) {
        [IO.File]::WriteAllText((Join-Path $runtime 'phase.txt'), "$phase")
        $arguments = @(
            ('--extensionDevelopmentPath="{0}"' -f (Join-Path $repo '.ai-apps/embedroid/extension')),
            ('--extensionDevelopmentPath="{0}"' -f (Join-Path $PSScriptRoot '../vscode-android')),
            ('--extensionDevelopmentPath="{0}"' -f (Join-Path $runtime 'controller')),
            ('--user-data-dir="{0}"' -f (Join-Path $runtime 'profile')),
            ('--extensions-dir="{0}"' -f (Join-Path $runtime 'extensions')),
            '--new-window', '--skip-welcome', '--skip-release-notes', '--disable-workspace-trust',
            ('"{0}"' -f $Workspace)
        )
        $hostProcess = Start-Process -FilePath $codeExe -ArgumentList $arguments -WindowStyle Hidden -PassThru -WorkingDirectory $runtime `
            -RedirectStandardOutput "$runtime/stdout-$phase.log" -RedirectStandardError "$runtime/stderr-$phase.log"
        $null = $hostProcess.Handle
        # Poll instead of a long blocking wait; no effect on the user's editor.
        for ($i = 0; $i -lt 180 -and -not $hostProcess.HasExited; $i++) { Start-Sleep -Milliseconds 500 }
        if (-not $hostProcess.HasExited) { $hostProcess.Kill(); throw 'The isolated Android test host timed out.' }
        $hostProcess.WaitForExit()
        $report = Get-Content -Raw -Encoding UTF8 "$runtime/result-$phase.json" | ConvertFrom-Json
        if ($hostProcess.ExitCode -ne 0 -or -not $report.passed) { throw "Host phase $phase failed: $($report.error)" }
        Write-Output "PASS: isolated editor phase $phase; two real emulators, video, deduplication and independent reconnect/close."
    }
} finally { $env:ELECTRON_RUN_AS_NODE = $previous }
