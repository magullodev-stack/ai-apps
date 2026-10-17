# Pruebas puras de propiedad; no consultan WMI, no matan procesos ni tocan Android.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flutter-ownership.ps1')
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')).TrimEnd('\')
$runner = Join-Path $repo 'scripts\flutter-dev-runner.dart'
$defines = Join-Path $repo '.ai-apps\onboardingQuiz-defines.json'
$f5Defines = Join-Path $repo '.ai-apps\muondia-flutter-defines.json'

function Assert-Ownership([object[]]$Processes, [string]$Expected, [string]$Case) {
    $actual = Get-MuondiaFlutterOwnership -Processes $Processes -RepoRoot $repo
    if ($actual -ne $Expected) {
        throw "$Case : se esperaba '$Expected' y se obtuvo '$actual'."
    }
}

$ownRunner = [pscustomobject]@{
    CommandLine = ('dart.exe "' + $runner + '" --flutter flutter.bat --device emulator-5554')
}
$ownFlutter = [pscustomobject]@{
    CommandLine = ('dart.exe flutter_tools.snapshot run --dart-define-from-file="' + $defines + '" -d emulator-5554')
}
$f5Flutter = [pscustomobject]@{
    CommandLine = ('dart.exe flutter_tools.snapshot run --dart-define-from-file="' + $f5Defines + '" -d emulator-5554')
}
$unknownFlutter = [pscustomobject]@{
    CommandLine = 'dart.exe flutter_tools.snapshot run -d emulator-5554'
}
$otherRepo = [pscustomobject]@{
    CommandLine = 'dart.exe C:\otro-repo\scripts\flutter-dev-runner.dart --device emulator-5554'
}
$otherDevice = [pscustomobject]@{
    CommandLine = ('dart.exe "' + $runner + '" --device emulator-5556')
}
$noCommand = [pscustomobject]@{ CommandLine = $null }

Assert-Ownership @() 'free' 'Sin Flutter'
Assert-Ownership @($ownRunner) 'owned' 'Runner persistente propio'
Assert-Ownership @($ownFlutter) 'owned' 'Flutter hijo propio'
Assert-Ownership @($ownRunner, $ownFlutter) 'owned' 'Runner y Flutter hijo'
Assert-Ownership @($f5Flutter) 'foreign' 'F5 protegido'
Assert-Ownership @($ownRunner, $f5Flutter) 'foreign' 'Mixto, no recuperar'
Assert-Ownership @($unknownFlutter) 'foreign' 'Flutter desconocido'
Assert-Ownership @($otherRepo) 'foreign' 'Repositorio diferente'
Assert-Ownership @($otherDevice) 'foreign' 'Dispositivo diferente'
Assert-Ownership @($noCommand) 'foreign' 'Proceso sin comando'
Write-Output 'PASS: propiedad Flutter propia/ajena/mixta; F5 protegido.'
