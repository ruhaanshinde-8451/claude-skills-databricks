---
name: run-unit-test
description: Run unit tests for the claude-skills-databricks plugin using pytest without requiring Databricks credentials.
argument-hint: --repo-path <path> [--verbose]
---

# /run-unit-test

Run all unit tests for the plugin locally or in CI.

## Required Inputs
- `--repo-path <path>`: Path to the claude-skills-databricks repo root.

## Optional Inputs
- `--verbose`: Pass `-v` to pytest for detailed output.

## Copy/Paste Invocation
```bash
/run-unit-test --repo-path /path/to/claude-skills-databricks
```

## Execution
1. Validate `repo-path` exists and contains a `plugins/` directory.
2. Run unit tests:
```bash
   cd <repo-path> && pytest -m unit
```
   With verbose flag:
```bash
   cd <repo-path> && pytest -m unit -v
```
3. Capture exit code, stdout, and stderr.
4. Exit code `0` = all tests passed. Any other exit code = failure.

## Output Contract
```json
{
  "status": "success|failure|error",
  "message": "human-readable summary",
  "tests_passed": 0,
  "tests_failed": 0,
  "tests_collected": 0,
  "stdout": "<captured stdout, truncated to 2000 chars>",
  "stderr": "<captured stderr, truncated to 500 chars>"
}
```

## Success Criteria
- Exit code `0`
- `status=success`
- `tests_failed=0`

## Failure Criteria
- Exit code non-zero
- `status=failure`
- `tests_failed` populated
- `stdout` includes pytest failure details

## Error Handling
- If `pytest` is not installed: `status=error`, `message=pytest not found. Run pip install pytest.`
- If no tests collected: `status=error`, `message=No unit tests found. Ensure tests are marked with @pytest.mark.unit.`
- If `repo-path` does not exist: `status=error`, `message=repo-path not found.`

## Notes
- Tests must not require Databricks credentials — any test that does should be marked `@pytest.mark.integration` and is out of scope for this skill.
- This skill is safe to run in CI on PR without any Databricks auth setup.