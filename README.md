# Copilot Databricks Skills

A skills pack for Databricks Asset Bundle workflows.  
Install once, then use in **GitHub Copilot CLI** for validate/deploy/run and parameter validation.

---

## Prerequisites

1. GitHub Copilot CLI installed.
2. Databricks CLI installed and authenticated (`~/.databrickscfg`).
3. A Databricks Asset Bundle repo with `databricks.yml`.

---

## Installation

### Install all skills

```bash
curl -fsSL https://raw.githubusercontent.com/ruhaanshinde-8451/claude-skills-databricks/main/install-skills.sh | bash
```

### Install one skill

```bash
curl -fsSL https://raw.githubusercontent.com/ruhaanshinde-8451/claude-skills-databricks/main/install-skills.sh | bash -s -- --skill databricks-run-pipeline
```

### Replace existing installed version

```bash
curl -fsSL https://raw.githubusercontent.com/ruhaanshinde-8451/claude-skills-databricks/main/install-skills.sh | bash -s -- --force
```

For repo-scoped install (current repo only):

```bash
curl -fsSL https://raw.githubusercontent.com/ruhaanshinde-8451/claude-skills-databricks/main/install-skills.sh | bash -s -- --project
```

After install, run `/skills reload` (or open a new session).

---

## Available Skills

| Skill | Command | Description |
|---|---|---|
| Databricks Run Pipeline | `/databricks-run-pipeline` | Validate, deploy, run job, collect output, and summarize status |
| Databricks Integration Test | `/databricks-integration-test` | Compare expected vs actual task parameters for a completed run |

---

## Usage

### Recommended model for deploy flows

Before running deployment tasks in Copilot CLI, select:

```bash
/model claude-sonnet-4.6
```

### Databricks Run Pipeline

```bash
Use the /databricks-run-pipeline skill to run job <job_key> with target <target> and profile <profile>. Support flags: --skip-deploy, --no-strict, --no-wait, --integration-test, --skip-integration-test.
```

Examples:

```bash
/databricks-run-pipeline --job ruhaan_repo
/databricks-run-pipeline --job ruhaan_repo_regression_tests --target stg --profile stg
/databricks-run-pipeline --job ruhaan_repo --skip-deploy
```

### Databricks Integration Test

```bash
Use the /databricks-integration-test skill for run <run_id> and job <job_key> with target <target> and profile <profile>.
```

Example:

```bash
/databricks-integration-test 123456789 --job ruhaan_repo --target dev --profile dev
```

---

## Defaults and Guardrails

- Default target is `dev`.
- Default profile is same as target.
- `prd` requires explicit confirmation.
- Auth failures must report the exact failing command.
- Output is compact and structured for handoff.

---

## Notes

This repository is **Copilot-skills-first**. Skills are distributed from `plugins/.../SKILL.md` and installed via `install-skills.sh` into `~/.copilot/skills` (or `.github/skills` with `--project`).
