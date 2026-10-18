# Ejecuta las funciones de produccion con procesos/ADB simulados. Nunca
# consulta WMI, lanza Android, termina procesos ni espera tiempo real.
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$launcher = Join-Path $repo 'scripts/start-ai-apps-android.ps1'
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) { throw 'El preparador Android no se puede analizar.' }
foreach ($definition in $ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst]
}, $false)) {
    . ([scriptblock]::Create($definition.Extent.Text))
}

$AvdName = 'AI_APPS_Dev'
$Serial = 'emulator-5554'
$port = 5554
$SystemImage = 'fixture'
$emulator = 'Get-FixtureAvds'
$avdmanager = 'Never-CreateFixtureAvd'

function New-FixtureProcess([string]$Name, [int]$ProcessId, [int]$ParentProcessId = 1,
    [string]$CommandLine = '-avd AI_APPS_Dev -port 5554') {
    [pscustomobject]@{ Name = $Name; ProcessId = $ProcessId;
        ParentProcessId = $ParentProcessId; CommandLine = $CommandLine;
        CreationDate = [datetime]'2026-10-18T12:00:00' }
}
function Get-CimInstance {
    param([string]$ClassName, [string]$Filter)
    if ($Filter -match '^ProcessId=([0-9]+)$') {
        $id = [int]$Matches[1]
        if ($global:avdStartupFixture.ReusedPid -eq $id) {
            $changed = New-FixtureProcess 'emulator.exe' $id
            $changed.CreationDate = $changed.CreationDate.AddSeconds(1)
            return $changed
        }
        return @($global:avdStartupFixture.Processes | Where-Object { $_.ProcessId -eq $id })
    }
    return $global:avdStartupFixture.Processes
}
function Test-EmulatorReady {
    return $global:avdStartupFixture.Ready -or $global:avdStartupFixture.Elapsed -ge $global:avdStartupFixture.ReadyAfter
}
function Get-SerialState { return $global:avdStartupFixture.State }
function Get-FixtureAvds { return 'AI_APPS_Dev' }
function Test-Path {
    param([string]$LiteralPath)
    if ($LiteralPath -like '*muondia-f5-takeover.txt') {
        return $global:avdStartupFixture.F5 -or
            $global:avdStartupFixture.Elapsed -ge $global:avdStartupFixture.F5At
    }
    return Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath
}
function Start-Sleep {
    param([int]$Seconds)
    $global:avdStartupFixture.Elapsed += $Seconds
    if ($global:avdStartupFixture.SpawnChildAt -gt 0 -and
        $global:avdStartupFixture.Elapsed -ge $global:avdStartupFixture.SpawnChildAt -and
        -not @($global:avdStartupFixture.Processes | Where-Object { $_.Name -like 'qemu-*' }).Count) {
        $global:avdStartupFixture.Processes += New-FixtureProcess 'qemu-system-x86_64-headless.exe' 102 101 ''
    }
}
function Start-Process {
    param($FilePath, $ArgumentList, $WindowStyle)
    if (@(Get-ManagedAvdProcesses).Count -gt 0) { throw 'Intento de duplicar AVD vivo.' }
    if ($WindowStyle -ne 'Hidden') { throw 'Arranque visible inesperado.' }
    $global:avdStartupFixture.Starts++
    $global:avdStartupFixture.Ready = $true
}
function taskkill.exe {
    if ($args -contains '/T') { throw 'Nunca terminar el arbol del wrapper.' }
    $pidIndex = [array]::IndexOf($args, '/PID')
    $id = [int]$args[$pidIndex + 1]
    if ($global:avdStartupFixture.Elapsed -lt 16) { throw 'Wrapper terminado antes de la espera.' }
    $target = @($global:avdStartupFixture.Processes | Where-Object { $_.ProcessId -eq $id })
    if ($target.Count -ne 1 -or $target[0].Name -ne 'emulator.exe') {
        throw 'Se intento terminar QEMU u otro proceso.'
    }
    $global:avdStartupFixture.Killed += $id
    $global:avdStartupFixture.Processes = @($global:avdStartupFixture.Processes | Where-Object { $_.ProcessId -ne $id })
}
function Assert-Case([string]$Name, [object[]]$Processes, [string]$State,
    [int]$Starts = 0, [int[]]$Killed = @(), [string]$ErrorPattern = '',
    [int]$ReadyAfter = [int]::MaxValue, [bool]$Ready = $false,
    [bool]$F5 = $false, [int]$F5At = [int]::MaxValue,
    [int]$SpawnChildAt = 0, [int]$ReusedPid = 0) {
    $global:avdStartupFixture = @{ Processes = $Processes; State = $State; Starts = 0;
        Killed = @(); Elapsed = 0; ReadyAfter = $ReadyAfter; Ready = $Ready;
        F5 = $F5; F5At = $F5At; SpawnChildAt = $SpawnChildAt; ReusedPid = $ReusedPid }
    $failure = ''
    try { Initialize-ManagedAvd -RepoRoot $repo | Out-Null } catch { $failure = $_.Exception.Message }
    if ($ErrorPattern) {
        if ($failure -notmatch $ErrorPattern) { throw "$Name : error inesperado '$failure'." }
    } elseif ($failure) { throw "$Name : $failure" }
    if ($global:avdStartupFixture.Starts -ne $Starts -or
        ($global:avdStartupFixture.Killed -join ',') -ne ($Killed -join ',')) {
        throw "$Name : inicio/parada inesperados."
    }
}

$wrapper = New-FixtureProcess 'emulator.exe' 101
$headless = New-FixtureProcess 'qemu-system-x86_64-headless.exe' 102 101
$armHeadless = New-FixtureProcess 'qemu-system-aarch64-headless.exe' 102 101
Assert-Case 'Sesion lista permanece intacta' @($wrapper, $headless) 'device' -Ready $true
Assert-Case 'Corte ADB temporal conserva QEMU' @($wrapper, $headless) 'missing' -ReadyAfter 20
Assert-Case 'QEMU offline vivo no se mata ni duplica' @($wrapper, $headless) 'offline' `
    -ErrorPattern 'no termin'
Assert-Case 'Headless sin wrapper tampoco se duplica' @($headless) 'missing' `
    -ErrorPattern 'no termin'
Assert-Case 'ARM headless se conserva' @($armHeadless) 'offline' -ErrorPattern 'no termin'
$childWithoutArgs = New-FixtureProcess 'qemu-system-x86_64-headless.exe' 102 101 ''
Assert-Case 'Hijo sin argumentos protege wrapper' @($wrapper, $childWithoutArgs) 'missing' `
    -ErrorPattern 'no termin'
Assert-Case 'Hijo aparece durante arranque lento' @($wrapper) 'missing' -SpawnChildAt 8 `
    -ErrorPattern 'no termin'
Assert-Case 'Crash QEMU deja wrapper huerfano recuperable' @($wrapper) 'offline' -Starts 1 -Killed @(101)
Assert-Case 'PID reutilizado no se termina ni duplica' @($wrapper) 'missing' -ReusedPid 101 `
    -ErrorPattern 'no termin'
Assert-Case 'Crash sin procesos permite arranque aunque fila offline' @() 'offline' -Starts 1
$foreign = New-FixtureProcess 'qemu-system-x86_64-headless.exe' 202 1 '-avd Otro_AVD -port 5554'
Assert-Case 'Puerto ajeno bloquea arranque y parada' @($foreign) 'missing' -ErrorPattern 'propiedad no verificada'
Assert-Case 'ADB desconocido no provoca recuperacion' @($wrapper) 'unknown' -ErrorPattern 'ADB no responde'
Assert-Case 'Cesion F5 no toca Android' @($wrapper) 'missing' -F5 $true -ErrorPattern 'F5 tiene cedido'
Assert-Case 'Cesion F5 durante espera protege wrapper' @($wrapper) 'missing' -F5At 8 `
    -ErrorPattern 'F5 tiene cedido'
$flutter = New-FixtureProcess 'dart.exe' 301 1 'dart.exe flutter_tools.snapshot run -d emulator-5554'
Assert-Case 'Flutter ajeno impide tocar wrapper' @($wrapper, $flutter) 'missing' -ErrorPattern 'Flutter ocupa'
Write-Output 'PASS: preparador real con fixtures ADB/QEMU, headless, cortes, orfandad, PID reutilizado, F5 y puerto ajeno.'
