# Restaurar solo si F5 desplazo una sesion persistente existente.
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$marker = Join-Path $repo '.ai-apps\muondia-f5-takeover.txt'
if (-not (Test-Path -LiteralPath $marker)) { return }
$control = Join-Path $repo 'scripts\android\task-control.ps1'
$free = $false
for ($i = 0; $i -lt 40; $i++) {
    $owner = (& $control -Action Check -Serial emulator-5554 | Out-String).Trim()
    if ($owner -eq 'free') {
        $free = $true
        break
    }
    Start-Sleep -Milliseconds 500
}
if (-not $free) {
    throw 'Flutter de F5 sigue activo. No se iniciara otra sesion sobre emulator-5554.'
}
Start-ScheduledTask -TaskName 'AI-APPS Development' -ErrorAction Stop
Remove-Item -LiteralPath $marker -Force
Write-Host 'Sesion de desarrollo persistente restaurada.'
