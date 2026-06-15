---
name: run-regression-test
description: Trigger the target repo's existing regression test suite in Databricks dev and monitor it to terminal state.
argument-hint: --repo-path <path> (--job-id <id> | --job-name <name>) --target dev [--poll-interval-sec 30] [--timeout-sec 3600] [--commit-sha <sha>] [--issue-number <n>]
---

# /run-regression-test

Trigger the regression test suite already defined in the target repo by running its Databricks job in regression mode, then poll until completion. This skill does not define tests — it executes the regression tests already present in the target repo.

## Required Inputs
- `--repo-path <path>`: Path to the Databricks bundle repo root.
- `--target <env>`: Environment to run against. This skill supports `dev` only.
- One of:
  - `--job-id <id>`
  - `--job-name <name>` (must resolve to exactly one Databricks job)

## Optional Inputs
- `--poll-interval-sec <seconds>`: Poll interval. Default `30`.
- `--timeout-sec <seconds>`: Max poll duration. Default `3600` (60 minutes — regression suites run longer than integration).
- `--commit-sha <sha>`: Git commit SHA to pass to the regression payload. Default: current HEAD (`git rev-parse HEAD`).
- `--issue-number <n>`: Issue number to pass to the regression payload. Default: `0`.

## Copy/Paste Invocation
```bash
/run-regression-test --repo-path /path/to/dab-repo --job-id 123456789 --target dev
```

## Execution
1. Validate `repo-path` exists and is a directory.
2. Validate `target=dev`; otherwise return `unsupported_target`.
3. Resolve job identifier:
   - If `--job-id` provided, use it directly.
   - If `--job-name` provided, resolve with Databricks CLI and require exactly one match.
4. Resolve `commit_sha`:
   - If `--commit-sha` provided, use it.
   - Otherwise auto-resolve:
```bash
     git -C <repo-path> rev-parse HEAD
```
5. Trigger the job in regression mode by overriding the notebook parameters:
```bash
   databricks jobs run-now --job-id <job_id> \
     --notebook-params '{
       "run_test": "regression",
       "commit_sha": "<commit_sha>",
       "issue_number": "<issue_number>"
     }' -o json
```
   Extract `run_id`.
6. Poll run state until terminal state or timeout:
```bash
   databricks runs get --run-id <run_id> -o json
```
   Terminal states: `SUCCESS`, `FAILED`, `CANCELED`.
7. Build run URL: `https://<workspace-host>#job/<job_id>/run/<run_id>`.
8. On failure, extract task-level error from run output:
```bash
   databricks jobs get-run-output --run-id <task_run_id> -o json
```
   Fallback to parent run output. Return `.error` (or concise trace summary if `.error` empty).

## Output Contract
```json
{
  "status": "success|failure|timeout",
  "error": "authentication_error|job_not_found|unsupported_target|run_failed|run_canceled|timeout|null",
  "message": "human-readable summary",
  "target": "dev",
  "run_mode": "regression",
  "job_id": "<resolved job id>",
  "job_name": "<resolved job name or input>",
  "run_id": "<run id>",
  "run_url": "<databricks run url>",
  "elapsed_seconds": 0,
  "commit_sha": "<resolved commit sha>",
  "issue_number": "<issue number>",
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

## Notes
- This skill executes the regression tests defined in the target repo — it does not define or contain test logic itself.
- Regression mode is triggered via the `run_test=regression` notebook parameter, consistent with the repo's existing DAB convention.
- Default timeout is higher than integration tests because regression suites run longer.
- Dev only. Do not run against tst, stg, or prd.