---
name: databricks-integration-test
description: Validate that each Databricks task run received the expected parameters from databricks.yml.
---

# /databricks-integration-test

Validate parameter correctness for a completed Databricks run.

## Inputs
- `run_id` (required)
- `--job <job_key>` (required)
- `--target` (default `dev`)
- `--profile` (default same as target)

## Procedure
1. Read `databricks.yml` and extract expected parameter keys per task in the selected job.
2. Fetch run metadata:
   ```bash
   databricks jobs get-run <run_id> --profile <profile> -o json
   ```
3. Compare actual vs expected parameters per task.
4. Return only deltas (missing/extra/incorrect).

## Output Contract
- `Run ID:`
- `Job:`
- `Parameter Validation:`
  - per task result
  - `Missing:`
  - `Extra:`
  - `Incorrect Values:`
- `Overall:`
- `Next Action:`

## Guardrails
- Do not expose secrets.
- Do not invent parameter values.
- If metadata is incomplete, report uncertainty explicitly.
