# Sincronización bidireccional manual de dev para todo AI-APPS.
# Funciona desde cualquier proyecto/carpeta del repositorio.
# Sincroniza todos los cambios no ignorados y cualquier carpeta
# .ai-apps/experimentos-* existente.
$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -C $script:Repo @Arguments 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if (-not $AllowFailure -and $code -ne 0) {
        throw "Git no pudo completar: git $($Arguments -join ' '). $($output | Out-String)"
    }

    [pscustomobject]@{
        Code = $code
        Output = $output
    }
}

function Get-Text {
    param([object]$Value)
    (($Value | Out-String).Trim())
}

function Stage-SyncContent {
    Invoke-Git -Arguments @('add', '-A') | Out-Null

    $experimentsRoot = Join-Path $script:Repo '.ai-apps'
    if (Test-Path -LiteralPath $experimentsRoot) {
        Get-ChildItem -LiteralPath $experimentsRoot -Directory -Filter 'experimentos-*' |
            ForEach-Object {
                $relative = ".ai-apps/$($_.Name)"
                Invoke-Git -Arguments @('add', '-f', '-A', '--', $relative) | Out-Null
            }
    }
}

function Commit-StagedChanges {
    $staged = Get-Text (Invoke-Git -Arguments @(
        'diff', '--cached', '--name-only'
    )).Output

    if ([string]::IsNullOrWhiteSpace($staged)) {
        return $false
    }

    $repoName = Split-Path $script:Repo -Leaf
    Invoke-Git -Arguments @(
        'commit', '-m', "Sincronizar $repoName"
    ) | Out-Null
    return $true
}

try {
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCommand) {
        throw 'Git no está disponible en PATH.'
    }

    # Resolver siempre la raíz Git a partir de la ubicación real del script.
    # Así no importa desde qué proyecto o subcarpeta se invoque.
    $script:Repo = Get-Text (& git -C $PSScriptRoot rev-parse --show-toplevel 2>&1)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($script:Repo)) {
        throw 'No se pudo localizar la raíz del repositorio Git.'
    }

    $branch = Get-Text (Invoke-Git -Arguments @(
        'symbolic-ref', '--quiet', '--short', 'HEAD'
    )).Output

    if ($branch -ne 'dev') {
        throw "La rama actual es '$branch'. Este sincronizador solo publica dev."
    }

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Write-Host "SINCRONIZAR DEV — intento $attempt/3" -ForegroundColor Cyan

        Write-Host '1/5 Preparando cambios locales...'
        Stage-SyncContent
        if (Commit-StagedChanges) {
            Write-Host '    Commit local creado.'
        }
        else {
            Write-Host '    No hay cambios locales nuevos.'
        }

        Write-Host '2/5 Consultando origin/dev...'
        Invoke-Git -Arguments @(
            'fetch', '--no-tags', 'origin', 'dev'
        ) | Out-Null

        Write-Host '3/5 Integrando origin/dev mediante rebase...'
        $rebase = Invoke-Git -Arguments @(
            'rebase', 'refs/remotes/origin/dev'
        ) -AllowFailure

        if ($rebase.Code -ne 0) {
            Invoke-Git -Arguments @('rebase', '--abort') -AllowFailure | Out-Null
            throw 'Conflicto durante el rebase. Se ha abortado y no se ha publicado nada.'
        }

        Write-Host '4/5 Publicando dev...'
        $push = Invoke-Git -Arguments @(
            'push', 'origin', 'dev'
        ) -AllowFailure

        if ($push.Code -ne 0) {
            $pushText = Get-Text $push.Output
            if ($attempt -lt 3 -and
                $pushText -match 'rejected|fetch first|non-fast-forward') {
                Write-Host '    origin/dev cambió durante la publicación; reintentando...' -ForegroundColor Yellow
                continue
            }
            throw "Error al publicar en GitHub. $pushText"
        }

        Write-Host '5/5 Verificando sincronización...'
        Invoke-Git -Arguments @(
            'fetch', '--no-tags', 'origin', 'dev'
        ) | Out-Null

        $local = Get-Text (Invoke-Git -Arguments @(
            'rev-parse', 'HEAD'
        )).Output
        $remote = Get-Text (Invoke-Git -Arguments @(
            'rev-parse', 'refs/remotes/origin/dev'
        )).Output

        # Captura también archivos que pudieran haberse generado mientras
        # la sincronización estaba en curso. Si aparecen, se hace otro ciclo.
        Stage-SyncContent
        $newStaged = Get-Text (Invoke-Git -Arguments @(
            'diff', '--cached', '--name-only'
        )).Output

        if ($local -eq $remote -and [string]::IsNullOrWhiteSpace($newStaged)) {
            Write-Host "SINCRONIZACION COMPLETADA — dev = origin/dev ($($local.Substring(0, 7)))" -ForegroundColor Green
            exit 0
        }

        if ($attempt -lt 3) {
            if (-not [string]::IsNullOrWhiteSpace($newStaged)) {
                Write-Host '    Aparecieron cambios locales durante la sincronización; reintentando...' -ForegroundColor Yellow
            }
            else {
                Write-Host '    origin/dev cambió durante la verificación; reintentando...' -ForegroundColor Yellow
            }
            continue
        }

        throw 'No se pudo estabilizar dev tras tres intentos.'
    }

    throw 'No se pudo completar la sincronización.'
}
catch {
    Write-Error "SINCRONIZAR DEV: $($_.Exception.Message)"
    exit 1
}
