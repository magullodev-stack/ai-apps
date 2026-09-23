# HERRAMIENTAS.md — AI-APPS

## Catálogo

| Herramienta | Finalidad | Ubicación | Estado |
| --- | --- | --- | --- |
| Ejecución Android | Ejecutar manualmente la prueba Flutter desde Windows. | [`scripts/run-android.ps1`](../scripts/run-android.ps1) | Activa. Instrucciones en [`apps/quiz10/README.md`](../apps/quiz10/README.md). |

| MONIT-AI | Observación, consumo, costes y auditorías de las ejecuciones de IA. | `tools/monit-ai/` en la rama de respaldo indicada abajo. | Archivada; retirada de la base activa. |

---

COMMIT

git add -A; git diff --cached --check; if ($LASTEXITCODE -eq 0) { git commit -m "chore: actualizar AI-APPS"; if ($LASTEXITCODE -eq 0) { git push origin dev } }