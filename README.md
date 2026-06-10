# Copilot Databricks Skills

Skills pack for Databricks Asset Bundle workflows. Install once, then use in GitHub Copilot CLI or Claude Code to validate, deploy, run, and test Databricks jobs end to end.

## Prerequisites

1. GitHub Copilot CLI or Claude Code.
2. Databricks CLI installed and authenticated with `~/.databrickscfg`.
3. A Databricks Asset Bundle repo with `databricks.yml` at repo root.

## Installation

### Quick install (recommended)

From target repo root:

```bash
curl -fsSL https://raw.githubusercontent.com/ruhaanshinde-8451/claude-skills-databricks/main/install-skills.sh | bash -s -- --project
```

Then reload skills:

```bash
/skills reload
/skills list
```

You should see:
- `databricks-run-pipeline`
- `databricks-integration-test`

### Other install options

Install as personal skills:

```bash
curl -fsSL https://raw.githubusercontent.com/ruhaanshinde-8451/claude-skills-databricks/main/install-skills.sh | bash
```

Install a single skill:

```bash
curl -fsSL https://raw.githubusercontent.com/ruhaanshinde-8451/claude-skills-databricks/main/install-skills.sh | bash -s -- --skill databricks-run-pipeline
```

Overwrite existing installed version:

```bash
curl -fsSL https://raw.githubusercontent.com/ruhaanshinde-8451/claude-skills-databricks/main/install-skills.sh | bash -s -- --project --force
```

Pin to a commit or tag by replacing `main` in the URL.

## Available skills

| Skill | Command | Description |
|---|---|---|
| Databricks Run Pipeline | `/databricks-run-pipeline` | Validate, deploy, run a bundle job, collect output, and summarize status |
| Databricks Integration Test | `/databricks-integration-test` | Compare expected vs actual task parameters for a completed run |

## Usage

### Databricks Run Pipeline

Usage:

```bash
/databricks-run-pipeline --job <job_key> [--target <target>] [--profile <profile>] [options]
```

Options:

| Flag | Default | Description |
|---|---|---|
| `--job` | required | Bundle job key to run |
| `--target` | `dev` | Bundle target |
| `--profile` | same as target | Databricks CLI profile |
| `--skip-deploy` | false | Skip the deploy step |
| `--no-strict` | false | Disable strict bundle validation |
| `--no-wait` | false | Submit run without waiting for completion |
| `--skip-integration-test` | false | Skip task parameter validation |

Examples:

```bash
/databricks-run-pipeline --job ruhaan_repo
/databricks-run-pipeline --job ruhaan_repo_regression_tests --target stg --profile stg
/databricks-run-pipeline --job ruhaan_repo --skip-deploy
```

### Databricks Integration Test

Usage:

```bash
/databricks-integration-test <run_id> --job <job_key> [--target <target>] [--profile <profile>]
```

Examples:

```bash
/databricks-integration-test 123456789 --job ruhaan_repo
/databricks-integration-test 123456789 --job ruhaan_repo --target stg --profile stg
```

## Defaults and guardrails

- Default target is `dev`.
- Default profile matches target.
- Running against `prd` requires explicit confirmation.
- Auth failures stop execution immediately and report the exact failing command.
- Secrets and tokens are never printed or requested.

## Contributing

1. Add your skill under `plugins/<skill-name>/SKILL.md`.
2. Follow the existing frontmatter format (`name`, `description`).
3. Open a PR with a brief description of the skill and the team or target it supports.
