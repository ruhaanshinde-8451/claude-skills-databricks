# Copilot Databricks Skills

An AI agent toolkit for automating the Databricks Asset Bundle (DAB) deployment lifecycle. Instead of manually running `databricks bundle deploy`, triggering a job, and checking the Databricks UI for results, you describe what you want in plain language and the agent runs the full validate → deploy → run → test loop for you, reporting back structured pass/fail results.




## Prerequisites

1. GitHub Copilot CLI (https://shorturl.at/54GBw) or Claude Code (https://claude.ai/code).
2. Databricks CLI installed and authenticated with `~/.databrickscfg`.
3. A Databricks Asset Bundle repo with `databricks.yml` at repo root.
4. A known repo root path to pass as `--repo-path` (all commands run from this path).

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
| Deploy DAB (dev/tst) | `/deploy-dab` | Deploy a Databricks Asset Bundle to `dev` or `tst` and return structured status/error output |
| Run Integration Test (dev) | `/run-integration-test` | Trigger a Databricks integration test job and poll to terminal state with structured results |

## Usage

### Recommended flow (default `dev`)

Use these two skills in sequence:

```bash
/deploy-dab --repo-path <path-to-dab-repo> --target dev
/run-integration-test --repo-path <path-to-dab-repo> (--job-id <id> | --job-name <name>) --target dev
```

Notes:
- Keep `--repo-path` the same across both commands.
- Run integration test after deploy so job config and code are in sync.

### Deploy DAB (`dev` or `tst`; default `dev`)

Usage:

```bash
/deploy-dab --repo-path <path-to-dab-repo> --target <dev|tst>
```

Example:

```bash
/deploy-dab --repo-path /Users/you/repos/my-dab --target dev
```

When to use:
- Use `dev` for normal development deployments.
- Use `tst` when you need to validate in testing environment.

### Run Integration Test (dev only)

Usage:

```bash
/run-integration-test --repo-path <path-to-dab-repo> (--job-id <id> | --job-name <name>) --target dev [--poll-interval-sec 30] [--timeout-sec 1800]
```

Example:

```bash
/run-integration-test --repo-path /Users/you/repos/my-dab --job-id 123456789 --target dev
```

Input tips:
- Use `--job-id` when you already know exact Databricks job id.
- Use `--job-name` when id is unknown and name is unique.
- Use `--timeout-sec` for long-running suites; keep `--poll-interval-sec` at default unless you need faster status updates.

## Defaults and guardrails

- Default target is `dev`.
- Default profile matches target.
- `deploy-dab` supports `dev` and `tst`; `run-integration-test` is `dev` only.
- Running against `prd` requires explicit confirmation.
- Auth failures stop execution immediately and report the exact failing command.
- Secrets and tokens are never printed or requested.

## Contributing

1. Add your skill under `plugins/<skill-name>/SKILL.md`.
2. Follow the existing frontmatter format (`name`, `description`).
3. Open a PR with a brief description of the skill and the team or target it supports.