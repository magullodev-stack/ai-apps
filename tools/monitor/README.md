
# MONIT-AI

MONIT-AI is the standalone AI usage and cost observation tool for AI-APPS.

It reads existing usage records to report AI consumption, attribute costs to applications and executions, and inspect historical activity. It does not launch observed applications or call AI models.

AI usage instrumentation and append-only recording remain in `core/ai`.

## Run

From the repository root:

```bash
./gradlew -q :tools:monitor:run
```

The default view displays a cost chart and a compact execution table for the currently integrated game history.

The chart shows the total AI cost of each game and a rolling average calculated from closed games. The table lists all recorded games from newest to oldest, with their number, state, and total cost.

The current default chart is a game-history view, not a cross-application chart. Other applications can be inspected through MONIT-AI's usage queries.

### Rolling averages

```bash
./gradlew -q :tools:monitor:run --args="--window=50"
```

Supported windows are 10, 25, 50 (default), and 100 closed games.

Early windows use the available closed-game count. Games in progress remain visible with provisional accumulated costs but do not affect rolling averages.

The current game-history integration distinguishes these states:

- `COMPLETED`: execution completed.
- `FAILED`: execution ended in failure.
- `IN_PROGRESS`: execution started but has no recorded terminal event.
- `UNKNOWN`: available records do not establish the execution's lifecycle state.

Rolling averages use completed and failed games. Games of unknown state remain visible in the individual cost history but are excluded from these averages.

An unavailable or indeterminable cost is not plotted as a measured value.

## Usage queries

```bash
# Global usage report
./gradlew -q :tools:monitor:run --args="--all"

# Usage for a specific application
./gradlew -q :tools:monitor:run --args="--app=<application-id>"

# Usage for a specific execution
./gradlew -q :tools:monitor:run --args="--app=<application-id> --work-unit=<id>"

# Usage for a specific model
./gradlew -q :tools:monitor:run --args="--model=<model-id>"

# Usage for a specific operation
./gradlew -q :tools:monitor:run --args="--operation=<operation-id>"
```

`--all` displays the technical usage report, including breakdowns by application, model, operation, and execution.

`--app`, `--model`, `--operation`, and `--work-unit` provide exact-match filtering.

An execution is identified by its application and `workUnitId`. Identical work-unit identifiers belonging to different applications remain separate.

The current game-history integration also supports a consolidated execution detail containing recorded AI calls, token consumption, costs, durations, results, and available audit information.

The default chart and table omit these technical details. They remain available through the corresponding detailed queries.

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
./gradlew -q :tools:monitor:run --args="--all"
```

Selecting an explicit file overrides automatic file discovery.

MONIT-AI does not move or rewrite historical usage records.

## Cost calculation

The total AI cost of an execution is the sum of the costs of all AI calls attributed to it, including retries and failed attempts when their consumption is recorded.

Each call uses its recorded rate snapshot when available.

If a call has no recorded rate, an explicit pricing file may provide a retrospective estimate for its model:

```bash
AI_APPS_PRICING_FILE="$PWD/.ai-apps/pricing.json" \
./gradlew -q :tools:monitor:run
```

Retrospectively estimated costs are identified as such. They are not presented as rates recorded at the time of the original call.

If required consumption or pricing information is missing, MONIT-AI reports the cost as partial or indeterminable rather than silently treating missing costs as zero.

Costs expressed in different currencies are not summed.

An execution in progress has a provisional accumulated cost that can change as further AI calls are recorded. A recorded terminal event closes its execution lifecycle.

Historical reports are recalculated from the available records whenever MONIT-AI runs. The underlying usage records are not modified.

## Data format

The JSONL usage format and pricing configuration are documented in [`core/ai/README.md`](../../core/ai/README.md).