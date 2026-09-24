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
if ($LASTEXITCODE -ne 0) { throw "Falló el push" }