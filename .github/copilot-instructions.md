# Copilot Efficiency Guardrails

These instructions apply to all tasks in this repository.

## Primary Objective
- Minimize token and tool usage while preserving correctness, safety, and delivery speed.

## Discovery Discipline
- Start with the smallest discovery step that can answer the question.
- Prefer targeted search over broad file reads:
  - Use `rg`/search for symbols and exact keys.
  - Read only relevant sections instead of whole files when possible.
- Avoid duplicate reads of the same file unless content changed.
- Stop exploring as soon as you have enough information to act.

## Execution Discipline
- Batch independent read-only tool calls in parallel.
- Do not run commands that have already succeeded unless inputs changed.
- Prefer one deterministic script over many ad-hoc commands when available.
- Avoid expensive operations (`find` across entire repo, large output commands) unless required.

## Editing Discipline
- Make the smallest possible change set.
- Avoid unrelated refactors and formatting-only edits.
- Update only files needed for the requested outcome.

## Response Discipline
- Keep user-facing responses concise by default.
- Report only decision-relevant output, not full command logs.
- Summarize failures with: what failed, why, and one next action.

## Stop Conditions
- If blocked by missing credentials, permissions, or required user choice, stop and ask one precise question.
- If a failure is not recoverable locally, do not loop retries; provide a concrete remediation step.

## Databricks-Specific Cost Controls
- Default `target=dev` unless explicitly specified.
- Require explicit confirmation for `prd` actions.
- Reuse `databricks/run_pipeline.sh` for validate/deploy/run flow to avoid repeated tool chatter.
- For integration validation, compare only required task parameters and summarize deltas.