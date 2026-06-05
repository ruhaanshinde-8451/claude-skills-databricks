# claude-skills-databricks

Centralized Claude Code agent for automating Databricks pipelines using the [Databricks CLI](https://docs.databricks.com/dev-tools/cli/index.html) and [Databricks Asset Bundles (DAB)](https://docs.databricks.com/dev-tools/bundles/index.html).

---

## What's in This Repo

```
CLAUDE.md                         # Agent system prompt — auto-loaded by Claude Code
.claude/
├── settings.json                 # Tool permissions
└── commands/
    ├── pipeline.md               # /pipeline — full end-to-end: validate → deploy → run → int tests
    ├── dab-deploy.md             # /dab-deploy — deploy to target environment
    ├── dab-validate.md           # /dab-validate — validate bundle config
    ├── dab-run.md                # /dab-run — trigger and monitor a run
    └── dab-int-test.md           # /dab-int-test — run integration tests on deployed jobs
```

---

## Getting Started

### Prerequisites

- [Databricks CLI v0.200+](https://docs.databricks.com/dev-tools/cli/install.html)
- Authenticated to your Databricks workspace (`databricks configure`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

### Setup

Pull this repo into your Databricks project (git subtree recommended so updates flow automatically):

```bash
git subtree add --prefix=.claude-databricks git@github.com:<your-org>/claude-skills-databricks.git main --squash
```

Then symlink or copy `CLAUDE.md` and `.claude/` into your project root. Claude Code picks them up automatically on the next session.

To update from this central repo later:

```bash
git subtree pull --prefix=.claude-databricks git@github.com:<your-org>/claude-skills-databricks.git main --squash
```

---

## Usage

Claude Code loads `CLAUDE.md` automatically — no agent picker needed. Use slash commands to trigger specific workflows:

| Command | Use For | Example |
|---------|---------|---------|
| `/pipeline` | Full end-to-end: validate → deploy → run → int tests | `/pipeline ingest_job dev` |
| `/dab-deploy` | Deploy bundle to a target environment | `/dab-deploy prod` |
| `/dab-validate` | Validate bundle config before deploying | `/dab-validate staging` |
| `/dab-run` | Trigger and monitor a job or pipeline | `/dab-run transform_job dev` |
| `/dab-int-test` | Run integration tests on a deployed job | `/dab-int-test dev` |

Or just describe what you want in plain language:

- _"Deploy and run the ingest job in dev"_
- _"Validate my bundle config"_
- _"Run the silver pipeline with a full refresh"_
- _"Create a new DLT pipeline for the gold layer"_

---

## Agent Capabilities

- **Author** `databricks.yml` and resource YAML from scratch or reverse-scaffold from an existing workspace resource
- **Validate** bundle configuration and explain errors
- **Deploy** bundles to target environments (with production confirmation gate)
- **Run** jobs and DLT pipelines, stream output, and help debug failures
- **Scaffold** new jobs, pipelines, and task definitions following team conventions
- **Explain** DAB concepts: targets, variables, cluster policies, permissions, `run_as`

---

## Roadmap

- [ ] GitHub Pull Request integration — read PR descriptions to auto-generate bundle changes
- [ ] Jira ticket integration — parse tickets to scaffold new job/pipeline resources
- [ ] CI/CD hook — auto-validate bundles on PR open
- [ ] Cost estimation skill — estimate cluster costs before deploying

---

## Contributing

Add new commands under `.claude/commands/<command-name>.md`. Follow the existing command structure:
1. State the goal in the first line
2. Use `$ARGUMENTS` to accept inline parameters
3. Include step-by-step instructions with exact CLI commands
4. Add a common errors/fixes table
