# HERRAMIENTAS.md — AI-APPS

## Catálogo

| Herramienta | Finalidad | Ubicación | Estado |
| --- | --- | --- | --- |
| Ejecución Android | Ejecutar manualmente la prueba Flutter desde Windows. | [`scripts/run-android.ps1`](../scripts/run-android.ps1) | Activa. Instrucciones en [`apps/quiz10/README.md`](../apps/quiz10/README.md). |
| MONIT-AI | Observación, consumo, costes y auditorías de las ejecuciones de IA. | `tools/monit-ai/` en la rama de respaldo indicada abajo. | Archivada; retirada de la base activa. |

## Código archivado

La rama local `backup/base-antes-limpieza-20260923-194634`, en el commit `40410a19600fbfb67e06a32a2f1ba2779dc9eb99`, conserva MONIT-AI, `ai/src/`, los módulos Kotlin/JVM de `core/`, sus pruebas y la configuración Gradle anterior.

Para consultar las instrucciones históricas desde PowerShell:

```powershell
git show backup/base-antes-limpieza-20260923-194634:tools/monit-ai/README.md
```

Para exportar el estado anterior a un archivo ZIP sin cambiar de rama:

```powershell
git archive --format=zip --output="$env:TEMP\ai-apps-base-20260923-194634.zip" backup/base-antes-limpieza-20260923-194634
```

MONIT-AI ya estaba excluido de la compilación activa antes de la limpieza. Su recuperación operativa requiere revisar sus dependencias, adaptar las instrucciones históricas y verificar sus pruebas.

## Mantenimiento

Las herramientas se incorporan a la compilación activa cuando su implementación y sus pruebas están integradas.

Las instrucciones técnicas de cada herramienta se mantienen en su documentación específica.
