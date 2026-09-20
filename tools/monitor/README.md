# MONITOR

MONITOR is the standalone observation tool for AI-APPS. It reads the existing JSONL usage records; it does not start Quiz10 Web or call models. Instrumentation and append-only recording remain in `core/ai`.

## Run

From the repository root:

```bash
./gradlew :tools:monitor:run
./gradlew :tools:monitor:run --args="--window=50"
```

The default report shows Quiz10's complete total-game-cost history, a horizontal chart with individual game costs and a closed-game rolling average, comparison with the previous window, the most recent ten games, and the newest game's detailed calls and audits. The window can be 10, 25, 50 (default), or 100 games. Early windows show their actual sample size. Each game point uses its total from every recorded AI call, including preparation, later play, failed calls, and retries. The chart marks completed, failed, in-progress, and unknown-status games separately. An in-progress point shows its provisional accumulated cost and updates as calls arrive. Rolling averages and comparisons use only completed and failed games; their windows count closed games, and early samples show the actual closed-game count. Unknown costs remain unknown and are not plotted as measured values.

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

Each call uses its recorded rate snapshot. If a call has no snapshot, an explicit `AI_APPS_PRICING_FILE` may supply a retrospective estimate for that model. The report labels historical rates and retrospective estimates separately. Missing rates or usage produce partial or indeterminable estimates; the missing model is named and the report points to `AI_APPS_PRICING_FILE`. Different currencies are not summed. The Quiz10 preparation cost covers every `coverage`, `review`, and `substitutions` call, including failed attempts. Development cost covers Luna and other later calls. Total cost includes both. A game with a recorded start and no terminal event is `IN_PROGRESS`; a terminal event yields `COMPLETED` or `FAILED`; older games without lifecycle events are `UNKNOWN`. The newest game detail lists each recorded call with model, operation, input and output tokens, estimated cost, duration, and result, followed by total game cost and token totals. Preparation and later-call subtotals appear only when those calls exist. The individual chart points use total game cost. Rolling averages and comparisons use that same total for closed games only. Incomplete costs prevent a complete average; they are not plotted as measured values. A game in progress has a provisional accumulated total; the completed or failed event closes its recorded total.

The JSONL format and pricing configuration are documented in [`core/ai/README.md`](../../core/ai/README.md).
