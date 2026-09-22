> Estado: código conservado durante la reconstrucción de AI-APPS. MONIT-AI todavía no está integrado en la compilación activa. Sus instrucciones de ejecución volverán a ser aplicables cuando se adapte y verifique la herramienta.


# MONIT-AI

MONIT-AI is the standalone AI usage and cost observation tool for AI-APPS.

It reads existing usage records to report AI consumption, attribute costs to applications and executions, and inspect historical activity. It does not launch observed applications or call AI models.

AI usage instrumentation and append-only recording remain in `core/ai`.

## Run

From the repository root:

```bash
AI_APPS_PRICING_FILE="$PWD/.ai-apps/pricing.json" \
./gradlew -q :tools:monit-ai:run
```

MONIT-AI starts a local read-only web application at `http://localhost:8081`. Open that address in a browser through the Dev Container port forwarding. The page reads the existing usage records on every request; refreshing it updates the view without starting Quiz10 or calling AI models. The server binds to the container's loopback interface.

The current visual integration shows Quiz10 as an expandable product with its accumulated cost and `systems/games/quiz10/` path. Inside it, the SVG chart plots each game's total AI cost in red and the rolling average of closed games in blue. Select a 10, 25, 50 (default), or 100-game window on the page. Games in progress and games with unknown lifecycle state stay in the individual history, but do not enter the rolling average. Indeterminable costs leave gaps in the chart.

Below the chart, each game appears once as an expandable execution, newest first. Its heading shows the game number, state, and total cost. Opening it reveals a table with one row per model and input tokens, output tokens, their separate estimated costs, and the model total. Technical work-unit IDs are not shown. Provisional, retrospective, partial, and indeterminable amounts are identified in the headings and tables.

## Files

MONIT-AI reads usage records from:

```text
.ai-apps/usage/ai-usage.jsonl
```

This path is relative to the repository root.

MONIT-AI also reads existing usage files under:

```text
apps/*/.ai-apps/usage/
```

Records are deduplicated by `recordId`.

To select a specific usage file, set `AI_APPS_USAGE_FILE`:

```bash
AI_APPS_USAGE_FILE="/path/to/ai-usage.jsonl" \
./gradlew -q :tools:monit-ai:run
```

Selecting an explicit file overrides automatic file discovery.

MONIT-AI does not move or rewrite historical usage records.

## Cost calculation

The total AI cost of an execution is the sum of the costs of all AI calls attributed to it, including retries and failed attempts when their consumption is recorded.

Each call uses its recorded rate snapshot when available.

If a call has no recorded rate, an explicit pricing file may provide a retrospective estimate for its model:

```bash
AI_APPS_PRICING_FILE="$PWD/.ai-apps/pricing.json" \
./gradlew -q :tools:monit-ai:run
```

Retrospectively estimated costs are identified as such. They are not presented as rates recorded at the time of the original call.

If required consumption or pricing information is missing, MONIT-AI reports the cost as partial or indeterminable rather than silently treating missing costs as zero.

Costs expressed in different currencies are not summed.

An execution in progress has a provisional accumulated cost that can change as further AI calls are recorded. A recorded terminal event closes its execution lifecycle.

Historical reports are recalculated from the available records whenever MONIT-AI runs. The underlying usage records are not modified.

## Data format

The JSONL usage format and pricing configuration are documented in [`core/ai/README.md`](../../core/ai/README.md).