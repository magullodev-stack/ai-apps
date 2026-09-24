# HERRAMIENTAS.md — AI-APPS

## Catálogo

| Herramienta | Finalidad | Ubicación | Estado |
| --- | --- | --- | --- |
| Ejecución Android | Ejecutar manualmente la prueba Flutter desde Windows. | [`scripts/run-android.ps1`](../scripts/run-android.ps1) | Activa. Instrucciones en [`apps/quiz10/README.md`](../apps/quiz10/README.md). |

| MONIT-AI | Observación, consumo, costes y auditorías de las ejecuciones de IA. | `tools/monit-ai/` en la rama de respaldo indicada abajo. | Archivada; retirada de la base activa. |

---

COMMIT

git add -A
if ($LASTEXITCODE -ne 0) { throw "Falló git add" }

git diff --cached --check
if ($LASTEXITCODE -ne 0) { throw "Hay errores en los cambios" }

git diff --cached --quiet
if ($LASTEXITCODE -eq 1) {
    git commit -m "sync"
    if ($LASTEXITCODE -ne 0) { throw "Falló el commit" }
} elseif ($LASTEXITCODE -ne 0) {
    throw "Falló git diff"
}

git pull --rebase origin dev
if ($LASTEXITCODE -ne 0) { throw "Falló el pull; no se hizo push" }

git push origin dev
$ErrorActionPreference = 'Stop'

cd C:\Users\Miquelet\repos\ai-apps

if ((git branch --show-current) -ne 'dev') {
    throw "La rama activa no es dev"
}

# Comprobar y preparar los cambios locales
git status -sb

git add -A
if ($LASTEXITCODE -ne 0) { throw "Falló git add" }

git diff --cached --check
if ($LASTEXITCODE -ne 0) { throw "Hay errores en los cambios" }

# Crear un commit si existen cambios pendientes
git diff --cached --quiet

if ($LASTEXITCODE -eq 1) {
    git commit -m "sync"
    if ($LASTEXITCODE -ne 0) { throw "Falló el commit" }
}
elseif ($LASTEXITCODE -ne 0) {
    throw "Falló git diff"
}

# Sincronizar con GitHub conservando los commits locales
git pull --rebase origin dev
if ($LASTEXITCODE -ne 0) { throw "Falló el pull; no se hizo push" }

# Publicar los cambios
git push origin dev
if ($LASTEXITCODE -ne 0) { throw "Falló el push" }

# Confirmar el resultado
Write-Host "`nCOMMIT PUBLICADO:"
git rev-parse HEAD

Write-Host "`nESTADO FINAL:"
git status -sb