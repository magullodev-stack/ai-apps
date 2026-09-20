# AI usage recording

This module provides the technical AI usage recording shared by applications and games.

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


## Analysis and reports

MONITOR is the standalone tool in [`tools/monitor/README.md`](../../tools/monitor/README.md). It reads these technical records and produces the global and Quiz10 reports. The `core/ai` module only records technical events and does not depend on MONITOR.

Gradle launches Quiz10 Web from the repository root, so its default usage file is the path above. Older files under an application module remain readable by MONITOR without copying them.
