
# HERRAMIENTAS.md — AI-APPS

## Catálogo

| Herramienta | Finalidad | Ubicación | Documentación |
| --- | --- | --- | --- |
| Monitor de consumo y auditorías | Consultar llamadas a modelos, tokens, tiempos, costes estimados y resultados de auditoría. | `core/ai/` | `core/ai/README.md` |

## Uso del monitor

Consultar el histórico desde la raíz del repositorio:

```bash
./gradlew :apps:quiz10-web:run --args="--usage-monitor"
```

Consultar el consumo de una aplicación:

```bash
./gradlew :apps:quiz10-web:run --args="--usage-monitor --app=quiz10-web"
```

Consultar una unidad de trabajo concreta:

```bash
./gradlew :apps:quiz10-web:run --args="--usage-monitor --work-unit=<UUID>"
```

El monitor registra sus datos en `.ai-apps/usage/ai-usage.jsonl`. La variable `AI_APPS_USAGE_FILE` permite configurar otra ubicación.

El comando de consulta está disponible actualmente a través de `apps/quiz10-web/`; la herramienta es compartida y pertenece a `core/ai/`.

## Mantenimiento

Al incorporar una herramienta, añade al catálogo su nombre, finalidad, ubicación y documentación. Sus instrucciones técnicas se mantienen en su documento específico.