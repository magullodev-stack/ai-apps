# Sincronización bidireccional manual de dev.
# 1) guarda los cambios locales en un commit,
# 2) integra origin/dev mediante rebase,
# 3) publica dev,
# 4) verifica que local y remoto queden idénticos.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -C $repo @Arguments 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if (-not $AllowFailure -and $code -ne 0) {
        throw "Git no pudo completar: git $($Arguments -join ' '). $($output | Out-String)"
    }

    return [pscustomobject]@{
        Code = $code
        Output = $output
    }
}

try {
    $branch = ((Invoke-Git -Arguments @(
        'symbolic-ref', '--quiet', '--short', 'HEAD'
    )).Output | Out-String).Trim()

    if ($branch -ne 'dev') {
        throw "La rama actual es '$branch'. AI-APPS solo sincroniza dev."
    }

    Write-Host 'AI-APPS: preparando cambios locales...'
    Invoke-Git -Arguments @('add', '-A') | Out-Null

    $experiments = Join-Path $repo '.ai-apps\experimentos-luna-pd'
    if (Test-Path -LiteralPath $experiments) {
        Invoke-Git -Arguments @(
            'add', '-f', '-A', '--', '.ai-apps/experimentos-luna-pd'
        ) | Out-Null
    }

    $staged = ((Invoke-Git -Arguments @(
        'diff', '--cached', '--name-only'
    )).Output | Out-String).Trim()

    if ($staged.Length -gt 0) {
        Write-Host 'AI-APPS: guardando cambios locales...'
        Invoke-Git -Arguments @(
            'commit', '-m', 'Sincronizar AI-APPS'
        ) | Out-Null
    }
    else {
        Write-Host 'AI-APPS: no hay cambios locales nuevos que guardar.'
    }

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Write-Host "AI-APPS: integrando origin/dev (intento $attempt/3)..."
        Invoke-Git -Arguments @(
            'fetch', '--no-tags', 'origin', 'dev'
        ) | Out-Null

        $rebase = Invoke-Git -Arguments @(
            'rebase', 'refs/remotes/origin/dev'
        ) -AllowFailure

        if ($rebase.Code -ne 0) {
            Invoke-Git -Arguments @('rebase', '--abort') -AllowFailure | Out-Null
            throw 'Conflicto al integrar origin/dev. El rebase se ha abortado y no se ha publicado nada.'
        }

        $push = Invoke-Git -Arguments @(
            'push', 'origin', 'dev'
        ) -AllowFailure

        if ($push.Code -eq 0) {
            Invoke-Git -Arguments @(
                'fetch', '--no-tags', 'origin', 'dev'
            ) | Out-Null

            $local = ((Invoke-Git -Arguments @(
                'rev-parse', 'HEAD'
            )).Output | Out-String).Trim()

            $remote = ((Invoke-Git -Arguments @(
                'rev-parse', 'refs/remotes/origin/dev'
            )).Output | Out-String).Trim()

            if ($local -eq $remote) {
                Write-Host "SINCRONIZACION COMPLETADA — dev = origin/dev ($($local.Substring(0, 7)))" -ForegroundColor Green
                exit 0
            }

            if ($attempt -lt 3) {
                continue
            }

            throw 'El remoto cambió durante la sincronización y no pudo estabilizarse tras tres intentos.'
        }

        $pushText = ($push.Output | Out-String)
        if ($attempt -lt 3 -and
            ($pushText -match 'rejected|fetch first|non-fast-forward')) {
            continue
        }

        throw "Error al publicar en GitHub. $pushText"
    }

    throw 'No se pudo completar la sincronización.'
}
catch {
    Write-Error "AI-APPS: $($_.Exception.Message)"
    exit 1
}
