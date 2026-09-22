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

cd /workspaces/ai-apps

# 1. Comprobar qué has cambiado
git status -sb
git diff

# 2. Preparar los cambios
git add -A

# 3. Comprobar lo que vas a guardar
git diff --cached --check
git diff --cached --stat

# 4. Crear el commit (cambia el texto por una descripción real)
git commit -m "docs: actualizar arquitectura de AI-APPS"

# 5. Publicarlo en GitHub
git push origin dev

# 6. Confirmar el resultado
git status -sb
git rev-parse HEAD