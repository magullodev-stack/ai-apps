# MONITOR

MONITOR is the standalone observation tool for AI-APPS. It reads the existing JSONL usage records; it does not start Quiz10 Web or call models. Instrumentation and append-only recording remain in `core/ai`.

## Run

From the repository root:

```bash
./gradlew :tools:monitor:run
./gradlew :tools:monitor:run --args="--window=50"
```

The default report shows Quiz10's complete preparation-cost history, a horizontal rolling-average chart, comparison with the previous window, the most recent ten games, and the newest game's detailed calls and audits. The window can be 10, 25, 50 (default), or 100 games. Early windows show their actual sample size. Unknown costs remain unknown and are not plotted as measured values.

Other queries:

```bash
./gradlew :tools:monitor:run --args="--all"
./gradlew :tools:monitor:run --args="--app=quiz10-web --work-unit=<id>"
./gradlew :tools:monitor:run --args="--model=<id>"
./gradlew :tools:monitor:run --args="--operation=<id>"
```

`--all` gives the global report with application, model, operation, and execution breakdowns. An execution is identified by its application and `workUnitId`, so identical identifiers from different applications stay separate. `--app`, `--model`, `--operation`, and `--work-unit` retain the existing exact-match filtering behavior. A Quiz10 `--work-unit` query also includes its consolidated game detail. Audit rows include positions, reasons, and replacement attempts where recorded.

## Files and costs

The default path is `.ai-apps/usage/ai-usage.jsonl` at the repository root. MONITOR also reads existing usage files under `apps/*/.ai-apps/usage/` and deduplicates records by `recordId`. `AI_APPS_USAGE_FILE` selects one explicit file and overrides discovery. Gradle runs both the web application and MONITOR from the repository root for new recordings. No historical file is moved or rewritten.

Prices come from the rate snapshot on each call. Missing rates or usage produce partial or indeterminable estimates; different currencies are not summed. The Quiz10 preparation cost covers every `coverage`, `review`, and `substitutions` call, including failed attempts. Development cost covers Luna and other later calls. Total cost includes both. A game with a recorded start and no terminal event is `IN_PROGRESS`; a terminal event yields `COMPLETED` or `FAILED`; older games without lifecycle events are `UNKNOWN`. The chart and rolling averages use preparation cost only.

The JSONL format and pricing configuration are documented in [`core/ai/README.md`](../../core/ai/README.md).
