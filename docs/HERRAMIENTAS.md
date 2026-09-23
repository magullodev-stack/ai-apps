# HERRAMIENTAS.md — AI-APPS

## Catálogo

| Herramienta | Finalidad | Ubicación | Estado |
| --- | --- | --- | --- |
| MONIT-AI | Observación, consumo, costes y auditorías de las ejecuciones de IA. | `tools/monit-ai/` | Código conservado. Pendiente de adaptación y reintegración en la compilación activa. |

## Mantenimiento

Las herramientas se incorporan a la compilación activa cuando su implementación y sus pruebas están integradas.

Las instrucciones técnicas de cada herramienta se mantienen en su documentación específica.


---

COMMIT 

git add -A; git diff --cached --check; if ($LASTEXITCODE -eq 0) { git commit -m "chore: actualizar AI-APPS"; if ($LASTEXITCODE -eq 0) { git push origin dev } }