#!/usr/bin/env bash
set -uo pipefail

REPO_PATH="/Users/r110563/ruhaan_repo"
JOB_KEY="ruhaan_repo"
TARGET="dev"
PROFILE="dev"

cd "$REPO_PATH" || exit 1

echo "=== VALIDATE ==="
databricks bundle validate --target "$TARGET" --profile "$PROFILE" || exit 1

echo "=== DEPLOY ==="
databricks bundle deploy --target "$TARGET" --profile "$PROFILE" || exit 1

echo "=== RUN ==="
RUN_JSON=$(databricks bundle run "$JOB_KEY" --target "$TARGET" --profile "$PROFILE" -o json)
RUN_ID=$(echo "$RUN_JSON" | grep -o '"run_id": *[0-9]*' | head -1 | grep -o '[0-9]*')
echo "run_id: $RUN_ID"

echo "=== RUN STATE ==="
databricks jobs get-run "$RUN_ID" --profile "$PROFILE" -o json \
  | grep -E '"life_cycle_state"|"result_state"'

echo "=== RUN OUTPUT ==="
databricks jobs get-run-output "$RUN_ID" --profile "$PROFILE" -o json \
  | grep -E '"error"|"result"' | head -20