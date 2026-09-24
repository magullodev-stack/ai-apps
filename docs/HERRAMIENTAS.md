# HERRAMIENTAS.md — AI-APPS

## Catálogo

| Herramienta | Finalidad | Ubicación | Estado |
| --- | --- | --- | --- |
| Ejecución Android | Ejecutar manualmente la prueba Flutter desde Windows. | [`scripts/run-android.ps1`](../scripts/run-android.ps1) | Activa. Instrucciones en [`apps/quiz10/README.md`](../apps/quiz10/README.md). |

| MONIT-AI | Observación, consumo, costes y auditorías de las ejecuciones de IA. | `tools/monit-ai/` en la rama de respaldo indicada abajo. | Archivada; retirada de la base activa. |

---

COMMIT

$ErrorActionPreference = 'Stop'

cd C:\Users\Miquelet\repos\ai-apps

if ((git branch --show-current) -ne 'dev') {
    throw "La rama activa no es dev"
}

# Corregir los saltos de línea del README
$path = 'apps/quiz10/README.md'
$fullPath = Join-Path (Get-Location).Path $path

$content = [System.IO.File]::ReadAllText($fullPath)

$content = $content.Replace("`r`n", "`n").Replace("`r", "`n")
$content = $content.TrimEnd("`n") + "`n"

[System.IO.File]::WriteAllText(
    $fullPath,
    $content,
    [System.Text.UTF8Encoding]::new($false)
)

# Preparar todas las modificaciones locales
git add -A
if ($LASTEXITCODE -ne 0) { throw "Falló git add" }

# Comprobar los cambios
git diff --cached --check
if ($LASTEXITCODE -ne 0) {
    throw "Quedan errores en los cambios. Revisa los mensajes anteriores."
}

# Crear el commit
git diff --cached --quiet

if ($LASTEXITCODE -eq 1) {
    git commit -m "sync"
    if ($LASTEXITCODE -ne 0) { throw "Falló el commit" }
}
elseif ($LASTEXITCODE -ne 0) {
    throw "Falló git diff"
}

# Sincronizar con GitHub
git pull --rebase origin dev
if ($LASTEXITCODE -ne 0) { throw "Falló el pull" }

# Publicar
git push origin dev
if ($LASTEXITCODE -ne 0) { throw "Falló el push" }

# Confirmar el resultado
Write-Host "`nCOMMIT PUBLICADO:"
git rev-parse HEAD

Write-Host "`nESTADO FINAL:"
git status -sb