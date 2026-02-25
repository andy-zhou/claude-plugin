---
name: skill-lab
description: Build and improve Claude Code skills through test-driven iteration with agent teams
user-invocable: true
allowed-tools: Read, Glob, Grep
---

# Skill Lab

Router for the skill-lab toolkit. Detects project state and recommends the right skill to invoke.

## Detection

Check the project directory for harness state:

1. **No `harness/` directory** — the project hasn't been initialized.
   - Tell the user: "No test harness found. Run `/skill-lab-init` to set up test infrastructure for your skill."

2. **`harness/` exists but no `harness/config.yml`** — partially initialized or legacy setup.
   - Tell the user: "Harness directory exists but is missing `config.yml`. Run `/skill-lab-init` to complete setup, or `/skill-lab-upgrade` if this was initialized with an older version."

3. **`harness/config.yml` exists but no scenarios in `harness/scenarios/`** — initialized but no tests designed.
   - Read `harness/config.yml` and display: skill name, type, description.
   - Tell the user: "Harness is set up but has no scenarios. Run `/skill-lab-add-scenario` to design your first test scenario."

4. **`harness/config.yml` + scenarios exist** — ready to run experiments.
   - Read `harness/config.yml` and display: skill name, type, description.
   - Count scenarios in `harness/scenarios/`.
   - Check `docs/experiment-log/` for the most recent experiment (date and score).
   - Display status summary and suggest next actions.

## Available Skills

| Command | Purpose |
|---------|---------|
| `/skill-lab-init` | One-time setup. Asks about your skill, scaffolds the harness, writes config. |
| `/skill-lab-add-scenario` | Design a test scenario with traps, rubric, and evaluator briefing. |
| `/skill-lab-experiment [scenario]` | Run an experiment: worktree, agent team, evaluation, commit results. |
| `/skill-lab-upgrade` | Sync templates from latest plugin version, apply migrations. |
