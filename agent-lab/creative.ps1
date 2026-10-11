param(
    [string]$Idea,
    [string]$Room,
    [ValidateSet('openai', 'gemini')][string]$Provider = 'openai',
    [string]$Model,
    [ValidateRange(1, 50)][int]$Rounds = 10,
    [switch]$Flutter,
    [switch]$Build,
    [switch]$Android,
    [string]$CodexPath
)
# Remember the API credential encrypted for this Windows account.
# .secrets/ is Git-ignored; the plaintext is only in this child process's environment.
$credentialProvider = $Provider
if ($Room) {
    $statePath = Join-Path (Resolve-Path -LiteralPath $Room).Path 'room.json'
    if (Test-Path -LiteralPath $statePath) {
        $savedRoom = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($savedRoom.provider -in @('openai', 'gemini')) { $credentialProvider = $savedRoom.provider }
    }
}
$keyName = if ($credentialProvider -eq 'gemini') { 'GEMINI_API_KEY' } else { 'OPENAI_API_KEY' }
$addedKey = $false
if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($keyName, 'Process'))) {
    $secrets = Join-Path $PSScriptRoot '.secrets'
    $secretPath = Join-Path $secrets "creative-$credentialProvider.key.dpapi"
    if (Test-Path -LiteralPath $secretPath) {
        try {
            $protected = (Get-Content -LiteralPath $secretPath -Raw -Encoding UTF8).Trim()
            $secure = ConvertTo-SecureString -String $protected -ErrorAction Stop
        } catch {
            throw "No se puede descifrar la clave guardada en $secretPath. Puedes borrar ese archivo y volver a iniciar la sala."
        }
    } else {
        Write-Host "Primera conexion a $credentialProvider. Introduce tu clave API una sola vez."
        Write-Host "Se guardara cifrada para tu usuario de Windows en agent-lab/.secrets/ (ignorado por Git)."
        $secure = Read-Host -Prompt "Clave API (entrada oculta)" -AsSecureString
        if ($null -eq $secure -or $secure.Length -eq 0) { throw 'No se ha introducido ninguna clave API.' }
        New-Item -ItemType Directory -Force -Path $secrets | Out-Null
        $protected = ConvertFrom-SecureString -SecureString $secure
        [IO.File]::WriteAllText($secretPath, $protected)
    }
    $handle = [IntPtr]::Zero
    try {
        $handle = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        $plaintext = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($handle)
        if ([string]::IsNullOrWhiteSpace($plaintext)) { throw 'La clave API esta vacia.' }
        [Environment]::SetEnvironmentVariable($keyName, $plaintext, 'Process')
        $addedKey = $true
    } finally {
        if ($handle -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($handle) }
        Remove-Variable plaintext -ErrorAction SilentlyContinue
    }
}

$ErrorActionPreference = 'Stop'
$python = Join-Path $PSScriptRoot '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $python)) { throw 'Instala primero agent-lab con install.ps1.' }
$arguments = @('-B', (Join-Path $PSScriptRoot 'creative.py'), '--rounds', "$Rounds", '--provider', $Provider)
if ($Idea) { $arguments += @('--idea', $Idea) }
if ($Room) { $arguments += @('--room', (Resolve-Path -LiteralPath $Room).Path) }
if ($Model) { $arguments += @('--model', $Model) }
if ($Flutter) { $arguments += '--flutter' }
if ($Build) { $arguments += '--build' }
if ($Android) { $arguments += '--android' }
if ($CodexPath) { $arguments += @('--codex', $CodexPath) }
try {
    & $python @arguments
    $code = $LASTEXITCODE
} finally {
    if ($addedKey) { [Environment]::SetEnvironmentVariable($keyName, $null, 'Process') }
}
exit $code
