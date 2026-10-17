# Clasificacion pura de la propiedad Flutter en emulator-5554.
# No termina procesos ni inicia sesiones. Puede probarse sin Android.
function Test-IsPersistentMuondiaProcess {
    param(
        [Parameter(Mandatory = $true)]$Process,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($Process.CommandLine)) { return $false }

    $repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
    $runnerPath = (Join-Path $repo 'scripts\flutter-dev-runner.dart').ToLowerInvariant()
    $definesPath = (Join-Path $repo '.ai-apps\onboardingQuiz-defines.json').ToLowerInvariant()
    $command = $Process.CommandLine.Replace('/', '\').ToLowerInvariant()

    # Los dos procesos pertenecientes a la tarea persistente:
    # (1) su runner Dart y (2) el flutter_tools con defines exclusivos.
    # Los defines de F5 son distintos; nunca se reconocen como propios.
    if ($command.Contains($runnerPath) -and
        $command -match '(?:^|\s)--device\s+["'']?emulator-5554(?:["'']|\s|$)') {
        return $true
    }
    if ($command.Contains($definesPath) -and
        ($command.Contains('flutter_tools.snapshot') -or
         $command.Contains('flutter_tools') -or
         $command.Contains('flutter run'))) {
        return $true
    }
    return $false
}

function Get-MuondiaFlutterOwnership {
    param(
        [AllowEmptyCollection()][object[]]$Processes,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    if ($null -eq $Processes -or $Processes.Count -eq 0) { return 'free' }
    # Una sola sesion ajena o no identificable bloquea cualquier recuperacion.
    foreach ($process in $Processes) {
        if (-not (Test-IsPersistentMuondiaProcess -Process $process -RepoRoot $RepoRoot)) {
            return 'foreign'
        }
    }
    return 'owned'
}
