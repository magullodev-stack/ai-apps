[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param([switch]$PurgeRuns, [switch]$PurgeSecrets, [switch]$RemoveLab)
$ErrorActionPreference = 'Stop'
$labRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
if ((Get-Item -LiteralPath $labRoot).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Refusing to remove a linked laboratory root.'
}
if (-not (Test-Path -LiteralPath (Join-Path $labRoot 'dependencies.json'))) { throw 'Not an agent-lab installation.' }
if ($RemoveLab -and (-not $PurgeRuns -or -not $PurgeSecrets)) {
    throw '-RemoveLab requires -PurgeRuns and -PurgeSecrets, because it deletes the complete laboratory.'
}
$runs = Join-Path $labRoot 'runs'
if (Test-Path -LiteralPath $runs) {
    foreach ($manifest in Get-ChildItem -LiteralPath $runs -Filter manifest.json -Recurse -File) {
        $state = Get-Content -LiteralPath $manifest.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($state.status -eq 'started') { throw 'A run is active or unfinished. Finish it before uninstalling.' }
    }
}
if ($RemoveLab) {
    if ((Split-Path $labRoot -Leaf) -ne 'agent-lab') { throw 'Complete removal requires a directory named agent-lab.' }
    if ($PSCmdlet.ShouldProcess($labRoot, 'Delete complete agent-lab')) { Remove-Item -LiteralPath $labRoot -Recurse -Force }
    return
}
$names = @('.venv', '.deps', '.tools', '.cache', '.python', '__pycache__', '.pytest_cache', 'uv.zip')
if ($PurgeRuns) { $names += 'runs' }
if ($PurgeSecrets) { $names += @('.secrets', '.codex', '.env') }
foreach ($name in $names) {
    $target = [IO.Path]::GetFullPath((Join-Path $labRoot $name))
    # Verify every absolute target before recursive removal, without crossing shells.
    if ((Split-Path $target -Parent) -ne $labRoot) { throw "Unsafe removal target: $target" }
    if (Test-Path -LiteralPath $target) {
        if ((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Refusing to traverse linked removal target: $target"
        }
        if ($PSCmdlet.ShouldProcess($target, 'Delete generated laboratory data')) {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
    }
}
