param(
    [ValidateSet('Check', 'Stop')][string]$Action,
    [string]$Serial = 'emulator-5554',
    [string]$RepoRoot
)
$ErrorActionPreference = 'Stop'
$escapedSerial = [regex]::Escape($Serial)
$processes = @(Get-CimInstance Win32_Process | Where-Object {
    $_.Name -in @('dart.exe', 'dartvm.exe') -and
    ($_.CommandLine -match ('--device\s+"?' + $escapedSerial + '(?:"|\s|$)') -or
     $_.CommandLine -match ('(?:--device-id|-d)\s+"?' + $escapedSerial + '(?:"|\s|$)'))
})
if ($Action -eq 'Check') {
    if ($processes.Count) { Write-Output 'busy' } else { Write-Output 'free' }
    return
}
if ($Serial -ne 'emulator-5554' -or -not $RepoRoot) { throw 'Stop controls only AI-APPS Development.' }
$runnerPath = Join-Path ([IO.Path]::GetFullPath($RepoRoot)) 'scripts\flutter-dev-runner.dart'
$runners = @($processes | Where-Object { $_.CommandLine -like ('*' + $runnerPath + '*') })
Stop-ScheduledTask -TaskName 'AI-APPS Development'
foreach ($runner in $runners) {
    # Recheck identity after stopping the task; never kill unrelated Dart/VS Code.
    $current = Get-CimInstance Win32_Process -Filter "ProcessId=$($runner.ProcessId)"
    if ($current -and $current.CreationDate -eq $runner.CreationDate -and $current.CommandLine -eq $runner.CommandLine) {
        & taskkill.exe /PID $runner.ProcessId /T /F | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not stop the identified QuizAI Flutter runner.' }
    }
}
$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
& (Join-Path $sdk 'platform-tools\adb.exe') -s emulator-5554 shell am force-stop com.aiapps.quizai | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not stop QuizAI application.' }
