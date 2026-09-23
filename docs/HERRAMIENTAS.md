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

cd /workspaces/ai-apps && git add -A && for f in .vscode/tasks.json .vscode/launch.json scripts/start-quiz10.sh; do if [ -f "$f" ]; then git add -f "$f"; fi; done && git diff --cached --check && git commit -m "chore: actualizar AI-APPS" && git push origin dev