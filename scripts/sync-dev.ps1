# Sincronización segura de la copia local al abrir AI-APPS en VS Code.
# No modifica cambios pendientes, no crea commits ni fuerza la rama dev.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent

function Invoke-Git {
    param([string[]]$Arguments)
    $output = & git -C $repo @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Git no pudo completar: git $($Arguments -join ' '). $($output | Out-String)"
    }
    return $output
}

try {
    $branch = (Invoke-Git -Arguments @('symbolic-ref', '--quiet', '--short', 'HEAD') | Out-String).Trim()
    if ($branch -ne 'dev') {
        Write-Warning "AI-APPS: rama actual '$branch'. Solo se sincroniza dev; no se modificó nada."
        exit 2
    }

    # Fetch primero: permite diagnosticar el estado real del remoto sin tocar archivos.
    Write-Host 'AI-APPS: consultando origin/dev...'
    Invoke-Git -Arguments @('fetch', '--no-tags', 'origin', 'dev') | Out-Null

    $local = (Invoke-Git -Arguments @('rev-parse', 'HEAD') | Out-String).Trim()
    $remote = (Invoke-Git -Arguments @('rev-parse', 'refs/remotes/origin/dev') | Out-String).Trim()

    if ($local -eq $remote) {
        $status = @(Invoke-Git -Arguments @('status', '--porcelain', '--untracked-files=normal'))
        if ($status.Count -gt 0) {
            Write-Warning 'AI-APPS: commits sincronizados, pero hay archivos locales modificados o sin seguimiento. No se han tocado.'
            exit 2
        }
        Write-Host "AI-APPS: local y origin/dev idénticos ($($local.Substring(0, 7)))."
        exit 0
    }

    # Nunca actualizar automáticamente con archivos modificados o sin seguimiento.
    $status = (Invoke-Git -Arguments @('status', '--porcelain', '--untracked-files=normal') | Out-String).Trim()
    if ($status.Length -gt 0) {
        Write-Warning 'AI-APPS: cambios locales pendientes. No se actualiza automáticamente; revisa git status.'
        exit 2
    }

    # El remoto debe contener toda la historia local. En divergencia, no rebase/reset.
    & git -C $repo merge-base --is-ancestor HEAD refs/remotes/origin/dev
    $ancestorCode = $LASTEXITCODE
    if ($ancestorCode -eq 1) {
        Write-Warning "AI-APPS: dev local ($($local.Substring(0, 7))) y origin/dev ($($remote.Substring(0, 7))) han divergido, o hay commits locales por publicar. Sincronización detenida, sin sobrescribir nada."
        Write-Host 'Consulta: git log --oneline --left-right --graph dev...origin/dev'
        exit 2
    }
    if ($ancestorCode -ne 0) {
        throw 'No se pudo comprobar la relación entre dev y origin/dev.'
    }

    Write-Host "AI-APPS: incorporando origin/dev ($($remote.Substring(0, 7))) mediante fast-forward..."
    Invoke-Git -Arguments @('merge', '--ff-only', 'refs/remotes/origin/dev') | Out-Null

    $result = (Invoke-Git -Arguments @('rev-parse', 'HEAD') | Out-String).Trim()
    if ($result -ne $remote) {
        throw 'El HEAD local no coincide con origin/dev tras el fast-forward.'
    }
    Write-Host "AI-APPS: sincronización correcta. dev = origin/dev ($($result.Substring(0, 7)))."
    exit 0
}
catch {
    Write-Warning "AI-APPS: no se pudo sincronizar: $($_.Exception.Message)"
    exit 1
}
