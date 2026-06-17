# Copilot/Claude Databricks Skills

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
- `deploy-dab`
- `run-integration-test`

### Other install options

Install as personal skills:

```bash
curl -fsSL https://raw.githubusercontent.com/ruhaanshinde-8451/claude-skills-databricks/main/install-skills.sh | bash
```

Install a single skill:

```bash
curl -fsSL https://raw.githubusercontent.com/ruhaanshinde-8451/claude-skills-databricks/main/install-skills.sh | bash -s -- --skill deploy-dab
```

Overwrite existing installed version:

```bash
curl -fsSL https://raw.githubusercontent.com/ruhaanshinde-8451/claude-skills-databricks/main/install-skills.sh | bash -s -- --project --force
```

Pin to a commit or tag by replacing `main` in the URL.

## Available skills

| Skill | Command | Description |
|---|---|---|
| Deploy DAB (dev) | `/deploy-dab` | Deploy a Databricks Asset Bundle to `dev` and return structured status/error output |
| Run Integration Test (dev) | `/run-integration-test` | Trigger a Databricks integration test job and poll to terminal state with structured results |

## Usage

### Recommended flow (dev)

Use these two skills in sequence:

```bash
/deploy-dab --repo-path <path-to-dab-repo> --target dev
/run-integration-test --repo-path <path-to-dab-repo> (--job-id <id> | --job-name <name>) --target dev
```

### Deploy DAB (dev only)

Usage:

```bash
/deploy-dab --repo-path <path-to-dab-repo> --target dev
```

Example:

```bash
/deploy-dab --repo-path /Users/you/repos/my-dab --target dev
```

### Run Integration Test (dev only)

Usage:

```bash
/run-integration-test --repo-path <path-to-dab-repo> (--job-id <id> | --job-name <name>) --target dev [--poll-interval-sec 30] [--timeout-sec 1800]
```

Example:

```bash
/run-integration-test --repo-path /Users/you/repos/my-dab --job-id 123456789 --target dev
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
