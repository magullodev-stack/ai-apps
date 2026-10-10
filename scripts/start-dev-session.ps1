param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$runtime = Join-Path $repo '.ai-apps'
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
$log = Join-Path $runtime 'dev-session.log'

# Solo estados conocidos: nunca volcar salida de la app, excepciones completas,
# variables de entorno, defines ni el token del servicio en este registro.
function Write-SessionLog([string]$Message) {
    Add-Content -LiteralPath $log -Encoding UTF8 -Value (
        '[{0}] {1}' -f [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'), $Message
    )
}

$stage = 'Android'
try {
    Write-SessionLog 'Preparando Android.'
    & (Join-Path $PSScriptRoot 'start-ai-apps-android.ps1') *>&1 | Out-Null
    Write-SessionLog 'Android preparado: emulator-5554.'
    $stage = 'QuizAI'
    Write-SessionLog 'Iniciando servicio Dart y sesion Flutter.'
    & (Join-Path $repo 'apps\quizai\run.ps1') -Device emulator-5554 *>&1 |
        ForEach-Object {
            $line = $_.ToString().Trim()
            if ($line -eq 'Hot reload automatico completado.' -or
                $line -eq 'Hot restart completado.') {
                Write-SessionLog $line
            } elseif ($line -like 'Hot reload automatico activo:*') {
                Write-SessionLog 'QuizAI preparado; hot reload automatico activo.'
            } elseif ($line -like 'Cambio detectado:*') {
                Write-SessionLog 'Cambio de codigo/asset detectado.'
            } elseif ($line -like 'Running Gradle task*') {
                Write-SessionLog 'Compilacion Gradle iniciada.'
            } elseif ($line -match '^Hot (reload|restart) fallo:') {
                Write-SessionLog 'ERROR: hot reload/restart fallido.'
            }
        }
    Write-SessionLog 'Sesion Flutter terminada.'
} catch {
    Write-SessionLog ('ERROR en {0}: {1}.' -f $stage, $_.Exception.GetType().Name)
    # Categorias fijas para errores operativos, sin incluir datos de la excepcion.
    if ($_.Exception.Message -like '*clave*') {
        Write-SessionLog 'Comprueba la clave DPAPI del usuario con el lanzador de QuizAI.'
    } elseif ($_.Exception.Message -like '*Flutter*') {
        Write-SessionLog 'Comprueba Flutter con el lanzador de QuizAI en PowerShell.'
    }
    exit 1
}
