# skill-lab

Evals-driven development for Claude Code skills. Design test scenarios with planted traps and grading rubrics, run experiments with agent teams in isolated worktrees, and iterate on your skill based on structured evaluator reports.

## Workflow

The core loop has four steps:

1. **Init** (`/skill-lab-init`) — One-time setup. Answers five questions about your skill (what it does, skill type, path, success criteria, failure concerns), then scaffolds a `harness/` directory with scripts, subagent templates, and config.

2. **Design scenarios** (`/skill-lab-add-scenario`) — Create a test scenario: choose a domain, plant 5-8 traps with ground truth, define a realistic target task, write grading rubrics (caught/partial/missed), and configure the evaluator mode. The scenario should feel like real work, not an obvious test.

3. **Run experiments** (`/skill-lab-experiment [scenario]`) — Creates a git worktree, runs setup scripts, spawns agent teams (skill-tester follows the skill, evaluator grades against the rubric), monitors without steering, tears down fixtures, records results, and merges back.

4. **Analyze and iterate** — Read the evaluator report, diagnose one failure at a time (missing guidance? unclear instructions? ignored instructions?), make targeted skill edits, then run again. The `analysis-playbook.md` guide walks through this in detail.

## Commands

| Command | Purpose |
|---------|---------|
| `/skill-lab` | Router — detects harness state and directs you to the right next step |
| `/skill-lab-init` | One-time setup — creates harness with config, scripts, and templates |
| `/skill-lab-add-scenario` | Design a test scenario with traps, rubric, and evaluator briefing |
| `/skill-lab-experiment [scenario]` | Run a full experiment with agent teams in an isolated worktree |
| `/skill-lab-upgrade` | Sync templates and apply migrations from the latest plugin version |

## Key Concepts

**Harness** — The `harness/` directory scaffolded by `/skill-lab-init`. Contains scripts (setup, teardown, prompt rendering), subagent prompt templates (skill-tester, evaluator-agent), scenario directories, and `config.yml` with your skill's metadata.

**Scenarios** — A scenario is a test environment with planted traps (things the skill should catch) and ground truth (the correct answers). Each scenario has an evaluator briefing (role, rubric, behavior rules) and a skill-tester context briefing (the task assignment). Scenarios can optionally include fixtures (mock servers, sample files) via `start-fixture.sh`/`stop-fixture.sh`.

**Skill types** — Your skill's type determines how experiments run:

| Type | Agents | Evaluator Mode | Team Lead Role |
|------|--------|----------------|----------------|
| Interactive | Skill Tester + Evaluator | Plays counterpart during test | Passive monitor |
| Autonomous | Skill Tester, then Evaluator | Grades output post-hoc | Passive monitor |
| Orchestration | Skill Tester + dynamic sub-agents | Grades output + coordination | Handles spawn/terminate requests |

**Experiment lifecycle** — Each experiment runs in an isolated git worktree: setup scripts create the experiment directory and render prompt templates, agents are spawned and monitored, teardown cleans up fixtures, results are committed in the worktree, then merged back to the main branch. Experiment logs are written to `docs/experiment-log/`.

## Deep Dives

- **[Scenario Design Guide](guides/scenario-design.md)** — Trap categories (structural, naming, behavioral, scope, relationship, documentation), rubric best practices, anti-patterns, and calibration by skill type.
- **[Analysis Playbook](guides/analysis-playbook.md)** — Diagnosing failures one at a time, chain-of-whys root cause analysis, overfitting watch, fix proposals, and the iteration pattern.

## Harness Directory Structure

After running `/skill-lab-init`, your project gets:

```
harness/
├── config.yml                  # Skill metadata and test configuration
├── CLAUDE.md                   # Trust boundary marker + harness docs
├── scripts/
│   ├── setup.sh                # Create experiment from scenario
│   ├── teardown.sh             # Clean up fixtures after experiment
│   └── render-prompt.sh        # Substitute template variables in prompts
├── subagents/
│   ├── skill-tester.md         # Prompt template for the skill-testing agent
│   └── evaluator-agent.md      # Prompt template for the evaluator agent
└── scenarios/                  # Your test scenarios go here
    └── <scenario-name>/
        ├── evaluator-briefing.md           # Role, ground truth, rubric
        ├── skill-tester-context-briefing.md # Task assignment and domain context
        ├── start-fixture.sh                # Optional: set up mock services
        └── stop-fixture.sh                 # Optional: tear down mock services

docs/experiment-log/            # Version-controlled experiment logs
experiments/                    # Agent-generated output (ephemeral, untrusted)
```

**Trust boundary:** `harness/` is human-authored and version-controlled. `experiments/` is agent-generated — never place a `CLAUDE.md` there.
