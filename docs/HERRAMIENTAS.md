# HERRAMIENTAS.md — AI-APPS

## Catálogo

| Herramienta | Finalidad | Ubicación | Estado |
| --- | --- | --- | --- |
| Ejecución Android | Ejecutar manualmente la prueba Flutter desde Windows. | [`scripts/run-android.ps1`](../scripts/run-android.ps1) | Activa. Instrucciones en [`apps/quiz10/README.md`](../apps/quiz10/README.md). |

## Mantenimiento

Las herramientas se incorporan a la plataforma cuando su implementación y sus pruebas están integradas.

Las instrucciones técnicas de cada herramienta se mantienen en su documentación específica.

---

COMMIT

git add -A; git diff --cached --check; if ($LASTEXITCODE -eq 0) { git commit -m "chore: actualizar AI-APPS"; if ($LASTEXITCODE -eq 0) { git push origin dev } }