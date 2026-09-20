# Global AI Usage Monitor

This repository includes a global AI usage monitor shared by applications and games.

## What is recorded

For each AI call:

- unique call id
- timestamp
- application id
- optional technical work unit id (for example, game session id)
- operation category (`coverage`, `review`, `substitutions`, `luna`, `other`)
- resolved model id
- duration
- success/error result
- token usage when available
- rate snapshot used for that call (when configured)

For application/game metrics events:

- application id
- optional work unit id
- metric name and numeric values

For audit events (including Quiz10 review by question position):

- application and optional work unit id
- audit name, phase and accepted/rejected result
- optional position (one-based), replacement attempt and short reason

Sensitive data is not recorded:

- API keys
- authorization headers
- prompts
- generated questions/answers
- player names

Audit reasons are trimmed, whitespace-normalized, limited to 180 characters and redact common credential terms. Do not put prompts, answers or personal data in audit reasons.

## Storage

- Default usage file: `.ai-apps/usage/ai-usage.jsonl`
- Override with environment variable: `AI_APPS_USAGE_FILE`

Each line is a JSON record. Writes are append-only and synchronized with a file lock.

## Pricing configuration

Set `AI_APPS_PRICING_FILE` to a JSON file:

```json
{
  "currency": "USD",
  "models": {
    "gpt-4.1-mini": {
      "inputCostPerMillion": "0.30",
      "outputCostPerMillion": "1.20"
    },
    "gpt-4.1": {
      "currency": "USD",
      "inputCostPerMillion": "2.00",
      "outputCostPerMillion": "8.00"
    }
  }
}
```

Notes:

- Costs are estimates, not official OpenAI billing.
- Missing rates or missing usage produce partial or non-determinable estimates.
- Rate snapshots are stored inside call records so historical costs remain stable.

## Usage query command

Run from the repository root:

```bash
./gradlew :apps:quiz10-web:run --args="--usage-monitor"
```

Optional filters:

```bash
./gradlew :apps:quiz10-web:run --args="--usage-monitor --app=quiz10-web --operation=coverage"
./gradlew :apps:quiz10-web:run --args="--usage-monitor --model=gpt-4.1-mini"
./gradlew :apps:quiz10-web:run --args="--usage-monitor --work-unit=<session-id>"
```

The output includes:

- recorded period
- success/failure counts
- known tokens in/out
- estimated total cost
- application breakdown
- model breakdown
- operation breakdown
- metric event values (including Quiz10 preparation duration/invalidated/replaced/attempts)
- audit events grouped by work unit and position, with phase, result, attempt and reason when present
- warning when total cost is partial or not determinable

For Quiz10, each game run gets its own technical work unit id, even inside the same web session.
This allows querying one specific game with `--work-unit=<id>`.

Use that id to inspect the rejected initial review for each position and the accepted or rejected replacement attempts:

```bash
./gradlew :apps:quiz10-web:run --args="--usage-monitor --app=quiz10-web --work-unit=<game-work-unit-id>"
```

Route validation issues appear under `global`; question reviews and replacements appear under `position N`. The command lists recorded audit events, including accepted replacements. If a recent preparation has no audit events, it reports `no rejections recorded` when its metric includes `audit_detail_version=1`; older records without that marker report `detail not recorded (legacy records)`. The `--model` and `--operation` filters apply to call records, so use `--app` and `--work-unit` when inspecting audit rows.

## Quiz10 historical preparation costs

The default `--usage-monitor` view reads the existing JSONL file without starting the web server or calling models. It reconstructs every `quiz10-web` test by `workUnitId`, orders tests by their first record and id, and shows a horizontal chart of rolling preparation cost, the latest 10 tests and the latest test's calls and audits.

```bash
./gradlew :apps:quiz10-web:run --args="--usage-monitor --window=50"
```

`--window` accepts 10, 25, 50 or 100 (default 50). Each point averages the available tests up to its position, capped at the selected window. A comparison uses the latest N tests and the immediately preceding N tests when both complete periods have known USD costs. The chart compresses its display when necessary while retaining all records in calculations. Unknown points remain blank.

Preparation costs include all `coverage`, `review` and `substitutions` calls, including failures and retries, using the rate snapshot on each call. `luna` and other later game calls are excluded. Missing usage or rates yield partial or indeterminable costs; different currencies are never added. The last-test audit detail uses recorded rejected positions, reasons and replacement attempts. An explicit zero rejection count requires the preparation metric or its audit detail marker.

Use `--all` for the previous global report. `--work-unit=<id>` and the `--app`, `--model`, `--operation` filters also select that report.

## Quiz10 game lifecycle and total AI consumption

Each new game writes persistent lifecycle metrics under its own `workUnitId`: `quiz10_game_started`, `quiz10_game_prepared`, `quiz10_game_preparation_failed`, `quiz10_game_execution_failed`, and `quiz10_game_completed`. The preparation metric is recorded as soon as preparation succeeds, before generating the first question. The completed event is written once after question ten. These records contain no player name, question, answer or prompt content.

The default historical report now reconstructs the status of each game from its events: `IN_PROGRESS` after a start without a terminal event, `COMPLETED` or `FAILED` after a terminal event, and `UNKNOWN` for older records without lifecycle events. A terminal event supplies the close time. Preparation, development and total AI costs are shown separately; total includes every registered call, including failed calls. The report retains partial and indeterminable estimates where usage or rates are missing and does not add different currencies. The rolling graph continues to use preparation costs only. Rejected rows are read from `invalidated_positions` in the preparation metric, with audit events as a fallback.

`--work-unit=<id>` keeps the existing filtered call and audit report and appends the consolidated Quiz10 game detail, including its lifecycle status and total cost. `--all` keeps the original global report.
