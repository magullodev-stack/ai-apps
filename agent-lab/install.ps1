param()
$ErrorActionPreference = 'Stop'
$labRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$dependency = Get-Content -LiteralPath (Join-Path $labRoot 'dependencies.json') -Raw -Encoding UTF8 | ConvertFrom-Json

function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Executable failed with exit code $LASTEXITCODE" }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git is required.' }
$toolsDir = Join-Path $labRoot '.tools'
New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
$uv = Join-Path $toolsDir 'uv.exe'
if (-not (Test-Path -LiteralPath $uv)) {
    $archive = Join-Path $toolsDir 'uv.zip'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $dependency.uv.url -OutFile $archive -UseBasicParsing
    $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $dependency.uv.sha256) { throw 'uv archive checksum mismatch.' }
    Expand-Archive -LiteralPath $archive -DestinationPath $toolsDir -Force
    Remove-Item -LiteralPath $archive -Force
}
$uvVersion = (& $uv --version | Out-String).Trim()
if ($uvVersion -notmatch ('^uv ' + [regex]::Escape($dependency.uv.version) + '(\s|$)')) {
    throw 'Unexpected uv version. Remove .tools and reinstall.'
}

$chatdev = Join-Path $labRoot '.deps/chatdev'
if (-not (Test-Path -LiteralPath $chatdev)) {
    Invoke-Checked git @('clone', '--depth', '1', '--branch', $dependency.chatdev.tag, $dependency.chatdev.repository, $chatdev)
}
$chatdevHead = (& git -C $chatdev rev-parse HEAD | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $chatdevHead -ne $dependency.chatdev.commit) { throw 'ChatDev revision mismatch.' }
$changes = (& git -C $chatdev status --porcelain --untracked-files=no | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $changes) { throw 'ChatDev dependency has local changes; restore or reinstall it.' }

$names = @('UV_PYTHON_INSTALL_DIR', 'UV_CACHE_DIR', 'UV_PROJECT_ENVIRONMENT', 'UV_NO_PROGRESS')
$oldValues = @{}
foreach ($name in $names) { $oldValues[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    $env:UV_PYTHON_INSTALL_DIR = Join-Path $labRoot '.python'
    $env:UV_CACHE_DIR = Join-Path $labRoot '.cache'
    $env:UV_PROJECT_ENVIRONMENT = Join-Path $labRoot '.venv'
    $env:UV_NO_PROGRESS = '1'
    Invoke-Checked $uv @('python', 'install', $dependency.python, '--no-bin')
    # Upstream uv.lock is used directly; no source vendoring or global packages.
    Invoke-Checked $uv @('sync', '--project', $chatdev, '--python', $dependency.python, '--frozen', '--no-dev')
}
finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $oldValues[$name], 'Process') }
}
Write-Host "Installed ChatDev $($dependency.chatdev.tag) at $($dependency.chatdev.commit)."
Write-Host 'Next: .\agent-lab\test.ps1 or .\agent-lab\run.ps1 -Offline -Instruction "Fix increment"'
