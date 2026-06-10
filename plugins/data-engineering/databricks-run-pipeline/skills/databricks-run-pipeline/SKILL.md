---
name: databricks-run-pipeline
description: Validate, deploy, run, and summarize a Databricks bundle job with optional parameter validation.
---

# /databricks-run-pipeline

Run end-to-end Databricks bundle automation for a Databricks Asset Bundle repo.

## Goal
1. Validate bundle configuration.
2. Deploy bundle for selected target/profile.
3. Run selected Databricks job.
4. Fetch run metadata and run output.
5. Optionally validate task parameters passed at runtime.
6. Return a concise status summary with failure details.

## Required Defaults
- If target is not provided, use `dev`.
- If profile is not provided, use the same value as target.
- Require an explicit job key before execution.

## Available Jobs
If `--job` is missing, read `databricks.yml`, list keys under `resources.jobs` and `resources.pipelines`, then ask which key to run.

## Execution
```bash
databricks bundle validate --target <target> --profile <profile> --strict
databricks bundle deploy --target <target> --profile <profile>
databricks bundle run <job_key> --target <target> --profile <profile> -o json
```

After run, fetch metadata and output:
```bash
databricks jobs get-run <run_id> --profile <profile> -o json
databricks jobs get-run-output <run_id> --profile <profile> -o json
```

## Safety Rules
- Never run destructive git commands.
- Never print or request secrets.
- If Databricks auth fails, stop and report the exact command that failed.
- Never run against `prd` without explicit user confirmation.

## Output Format
- `Target:`
- `Profile:`
- `Job:`
- `Validation:`
- `Deploy:`
- `Run ID:`
- `Run State:`
- `Failure Class:`
- `Notebook Output:`
- `Parameter Validation:`
- `Next Action:`
