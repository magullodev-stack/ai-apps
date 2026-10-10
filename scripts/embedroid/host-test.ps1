$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'build.ps1') | Out-Null
$runtime = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../.ai-apps/embedroid'))
New-Item -ItemType Directory -Force -Path "$runtime/host-profile", "$runtime/host-extensions", "$runtime/host-workspace" | Out-Null
$code = Get-Command code -ErrorAction Stop
$codeExe = [IO.Path]::GetFullPath((Join-Path (Split-Path $code.Source -Parent) '../Code.exe'))
$previous = $env:ELECTRON_RUN_AS_NODE
try {
    $env:ELECTRON_RUN_AS_NODE = $null
    # Two independent VS Code processes reopen the same isolated profile.
    # Each process opens and closes two real embedded streams.
    for ($cycle = 1; $cycle -le 2; $cycle++) {
        $result = Join-Path $runtime 'host-test-result.json'
        [IO.File]::WriteAllText($result, '{}')
        $hostArguments = @(
            ('--extensionDevelopmentPath="{0}"' -f (Join-Path $runtime 'extension')),
            ('--extensionTestsPath="{0}"' -f (Join-Path $PSScriptRoot 'host-test.cjs')),
            ('--user-data-dir="{0}"' -f (Join-Path $runtime 'host-profile')),
            ('--extensions-dir="{0}"' -f (Join-Path $runtime 'host-extensions')),
            '--new-window', '--skip-welcome', '--skip-release-notes',
            ('"{0}"' -f (Join-Path $runtime 'host-workspace'))
        )
        $testHost = Start-Process -FilePath $codeExe -ArgumentList $hostArguments -WindowStyle Hidden -WorkingDirectory $runtime -RedirectStandardOutput "$runtime/host-stdout-$cycle.log" -RedirectStandardError "$runtime/host-stderr-$cycle.log" -PassThru
        # Retain the process handle before it exits; otherwise Windows
        # PowerShell can report a null ExitCode despite WaitForExit succeeding.
        $null = $testHost.Handle
        if (-not $testHost.WaitForExit(60000)) {
            # Stop only the exact isolated test host, never the user's editor.
            $testHost.Kill()
            throw 'El host aislado de pruebas no terminó en 60 segundos.'
        }
        $testHost.WaitForExit()
        $report = Get-Content -Raw -LiteralPath $result | ConvertFrom-Json
        if ($testHost.ExitCode -ne 0 -or -not $report.passed) {
            throw "Falló el ciclo $cycle del host aislado: $($report.error)"
        }
        Copy-Item -LiteralPath $result -Destination "$runtime/host-test-result-$cycle.json" -Force
        Write-Host "PASS: reapertura aislada $cycle; dos webviews con vídeo y conexión al primer intento."
    }
}
finally { $env:ELECTRON_RUN_AS_NODE = $previous }
