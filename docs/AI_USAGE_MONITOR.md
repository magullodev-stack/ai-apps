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

Sensitive data is not recorded:

- API keys
- authorization headers
- prompts
- generated questions/answers
- player names

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
- model breakdown
- operation breakdown
- warning when total cost is partial or not determinable
