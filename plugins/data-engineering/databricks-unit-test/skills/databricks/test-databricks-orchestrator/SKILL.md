---
name: test-databricks-orchestrator
description: Generate focused tests for the Databricks orchestrator agent and its skills.
---

# Test Databricks Orchestrator

Generate or update tests for:
- `databricks-orchestrator`
- `deploy-dab`
- `run-integration-test`

## Use

When asked to test or harden the orchestration flow:
1. Inspect existing test patterns in the repo.
2. Prefer the smallest targeted pytest coverage that matches the behavior.
3. Mock Databricks CLI calls instead of hitting live Databricks.
4. Add or update tests only for the specific behavior under change.
5. Run the narrowest useful test command and report the result.

## Coverage targets

Focus on the behavior the Databricks skills actually own:
- deploy to `dev` only guard
- run trigger and terminal-state polling behavior
- timeout behavior with elapsed time output
- run URL generation
- task-level failure message extraction
- authentication and invalid bundle error shaping

## Guardrails

- Do not invent fixtures or helper APIs.
- Do not assume a test harness that does not exist.
- If repo test structure is unclear, inspect it first and follow local conventions.
