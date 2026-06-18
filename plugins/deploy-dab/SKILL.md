---
name: deploy-dab
description: Deploy a Databricks Asset Bundle to dev or tst and return structured deployment output.
argument-hint: --repo-path <absolute-or-relative-path> --target <dev|tst>
---

# /deploy-dab

Deploy Databricks Asset Bundle to **dev** or **tst** environment from specified repository path.

## Required Inputs
- `--repo-path <path>`: Path to the Databricks Asset Bundle repository root (must contain `databricks.yml` or `databricks.yaml`).
- `--target <env>`: Deployment target. Supported values: `dev`, `tst`. Default `dev`.

## Copy/Paste Invocation
```bash
/deploy-dab --repo-path /path/to/dab-repo --target dev
```

## Execution
1. Resolve and validate `repo-path`:
   - Directory must exist.
   - `databricks.yml` or `databricks.yaml` must exist at repo root.
2. If `target` is not `dev` or `tst`, stop with structured failure (`unsupported_target`).
3. Run from the provided repo path and capture both stdout and stderr:
```bash
   databricks bundle deploy -t <target> -p <target>
```
4. Capture command output as:
   - `stdout`: full standard output text
   - `stderr`: full standard error text

## Output Contract
Always return a structured object using this shape:

```json
{
  "status": "success|failure",
  "error": "authentication_error|invalid_bundle|unsupported_target|deployment_error|null",
  "message": "human-readable summary",
  "repo_path": "<resolved path>",
  "target": "<dev|tst>",
  "deployed_job_name": "<job key/name or unknown>",
  "job_url": "<databricks job url or unknown>",
  "stdout": "<captured stdout>",
  "stderr": "<captured stderr>"
}
```

## Success Criteria
On successful deploy:
- Set `status=success`.
- Populate `deployed_job_name` from deploy output when present; otherwise use `unknown`.
- Populate `job_url` from deploy output when present; otherwise set `unknown`.

## Failure Handling
Never return raw stack traces as the top-level `message`.

1. Authentication failure  
   If output contains patterns like `Unauthorized`, `invalid access token`, `profile ... not found`, or `permission denied`:
   - `status=failure`
   - `error=authentication_error`
   - `message=Databricks authentication failed for target <target>. Check CLI login/profile configuration and retry.`

2. Invalid bundle YAML / validation failure  
   If output contains bundle validation errors (for example: `validation failed`, YAML parse errors, unknown fields, schema errors):
   - `status=failure`
   - `error=invalid_bundle`
   - `message=<specific validation message from Databricks CLI>`

3. Other deploy failures  
   - `status=failure`
   - `error=deployment_error`
   - `message=Databricks bundle deploy failed for target <target>. Review stderr for details.`

## Manual Verification (Story requirement)
Run this skill end-to-end against representative DAB in `dev` and `tst` and confirm:
1. Success path returns `status=success`, job name, and job URL.
2. Invalid auth path returns `status=failure` and `error=authentication_error` with human-readable message.
3. Invalid bundle path returns `status=failure` and `error=invalid_bundle` including the CLI validation message.
