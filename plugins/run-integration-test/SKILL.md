---
name: run-integration-test
description: Trigger a Databricks integration test job in dev and monitor it to terminal state.
argument-hint: --repo-path <path> (--job-id <id> | --job-name <name>) --target dev [--poll-interval-sec 30] [--timeout-sec 1800] [--baseline-duration-sec <seconds>]
---

# /run-integration-test

Trigger a Databricks integration test job and poll until completion for the **dev** environment.

## Required Inputs
- `--repo-path <path>`: Path to the Databricks bundle repo root (used as working directory for CLI execution).
- `--target <env>`: Environment to run against. This skill supports `dev` only.
- One of:
  - `--job-id <id>`
  - `--job-name <name>` (must resolve to exactly one Databricks job)

## Optional Inputs
- `--poll-interval-sec <seconds>`: Poll interval. Default `30`.
- `--timeout-sec <seconds>`: Max poll duration. Default `1800` (30 minutes).
- `--baseline-duration-sec <seconds>`: Expected job duration baseline. If elapsed exceeds `3x` this value before hard timeout, flag as `slow_run` in output.

## Copy/Paste Invocation
```bash
/run-integration-test --repo-path /path/to/dab-repo --job-id 123456789 --target dev
```

## Execution
1. Validate `repo-path` exists and is a directory.
2. Validate `target=dev`; otherwise return `unsupported_target`.
3. Resolve job identifier:
   - If `--job-id` provided, use it directly.
   - If `--job-name` provided, resolve with Databricks CLI and require exactly one match.
4. Config drift check — compare deployed job config against `databricks.yml`:
```bash
   databricks bundle validate --target dev -o json
   databricks jobs get --job-id <job_id> -o json
```
   Check for drift in: `tasks`, `job_clusters`, `parameters`, `schedule`, `libraries`.
   - If drift detected: set `config_drift=true`, populate `config_drift_details` with differing fields.
   - Do not stop — proceed with run but surface drift in output.
5. Trigger job run:
```bash
   databricks jobs run-now --job-id <job_id> -o json
```
   Extract `run_id`.
6. Poll run state until terminal state or timeout:
```bash
   databricks runs get --run-id <run_id> -o json
```
   Terminal states: `SUCCESS`, `FAILED`, `CANCELED`.
   - If `--baseline-duration-sec` provided and `elapsed > 3x baseline`, set `slow_run=true` and continue polling.
7. Build run URL using workspace host and run ID:
   - `https://<workspace-host>#job/<job_id>/run/<run_id>`
8. If run fails, extract task-level error message from run output:
   - Prefer task-level output from:
```bash
     databricks jobs get-run-output --run-id <task_run_id> -o json
```
   - Fallback to parent run output:
```bash
     databricks jobs get-run-output --run-id <run_id> -o json
```
   - Return `.error` (or concise trace summary if `.error` empty).

## Output Contract
Return structured output:

```json
{
  "status": "success|failure|timeout",
  "error": "authentication_error|job_not_found|unsupported_target|run_failed|run_canceled|timeout|null",
  "message": "human-readable summary",
  "target": "dev",
  "job_id": "<resolved job id>",
  "job_name": "<resolved job name or input>",
  "run_id": "<run id>",
  "run_url": "<databricks run url>",
  "elapsed_seconds": 0,
  "slow_run": false,
  "config_drift": false,
  "config_drift_details": "<list of drifted fields or null>",
  "task_error_message": "<task-level error message or null>",
  "stdout": "<captured stdout>",
  "stderr": "<captured stderr>"
}
```

## Success Criteria
When run reaches `SUCCESS`:
- `status=success`
- `error=null`
- `run_url` populated

## Failure Criteria
When run reaches `FAILED`:
- `status=failure`
- `error=run_failed`
- `run_url` populated
- `task_error_message` populated from run output

When run reaches `CANCELED`:
- `status=failure`
- `error=run_canceled`
- `run_url` populated

When polling exceeds timeout:
- `status=timeout`
- `error=timeout`
- `elapsed_seconds` populated

## Error Handling
Authentication failures (for example `Unauthorized`, `invalid access token`, `profile not found`, `permission denied`) must return:
- `status=failure`
- `error=authentication_error`
- human-readable `message` (no raw stack trace as top-level message)

## Manual Verification
Verify end-to-end against the representative dev integration test job from the scaffold spike:
1. Successful job returns `status=success` and `run_url`.
2. Failing job returns `status=failure`, `run_url`, and `task_error_message`.
3. Timeout path returns `status=timeout` with `elapsed_seconds` when poll duration exceeds 30 minutes.
4. Config drift detected returns `config_drift=true` and `config_drift_details` with differing fields.
5. Slow run detected returns `slow_run=true` with `elapsed_seconds` populated.