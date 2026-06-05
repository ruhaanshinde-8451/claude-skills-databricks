# claude-skills-databricks

Centralized Claude agent and skills repository for automating Databricks pipelines using the [Databricks CLI](https://docs.databricks.com/dev-tools/cli/index.html) and [Databricks Asset Bundles (DAB)](https://docs.databricks.com/dev-tools/bundles/index.html).

---

## What's in This Repo

```
.github/
├── agents/
│   └── databricks-pipeline.agent.md       # Main orchestrator agent
├── instructions/
│   └── databricks-bundles.instructions.md # Auto-applied context for bundle YAML files
└── skills/
    ├── dab-deploy/                         # Deploy a bundle to a target environment
    │   ├── SKILL.md
    │   └── references/
    │       ├── bundle-schema.md            # databricks.yml schema reference
    │       └── cli-commands.md             # Full CLI command reference
    ├── dab-validate/                       # Validate bundle before deploying
    │   └── SKILL.md
    └── dab-run/                            # Trigger and monitor job/pipeline runs
        └── SKILL.md
```

---

## Getting Started

### Prerequisites

- [Databricks CLI v0.200+](https://docs.databricks.com/dev-tools/cli/install.html)
- Authenticated to your Databricks workspace (`databricks configure`)
- VS Code with [GitHub Copilot](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot) extension

### Using the Agent

1. Clone this repo into your Databricks project workspace (or add as a submodule)
2. Open the folder in VS Code
3. In GitHub Copilot Chat, select the **Databricks Pipeline Agent** from the agent picker
4. Describe what you want to do:
   - _"Deploy the ingest job to dev"_
   - _"Validate my bundle config"_
   - _"Create a new DLT pipeline for the silver layer"_
   - _"Run the transform job and show me the output"_

### Using Skills Directly

Type `/` in Copilot Chat to invoke a skill:

| Skill | Command | Use For |
|-------|---------|---------|
| Deploy | `/dab-deploy` | Deploy bundle to dev/staging/prod |
| Validate | `/dab-validate` | Check bundle config before deploying |
| Run | `/dab-run` | Trigger and monitor a job or pipeline |

---

## Agent Capabilities

The **Databricks Pipeline Agent** can:

- **Author** `databricks.yml` and resource YAML from scratch or from an existing workspace resource
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

Add new skills under `.github/skills/<skill-name>/SKILL.md`. Follow the existing skill structure:
1. Clear `description` with trigger keywords for agent discovery
2. Step-by-step `Procedure` section
3. Common errors and fixes table
4. Reference links to shared docs in `dab-deploy/references/`
