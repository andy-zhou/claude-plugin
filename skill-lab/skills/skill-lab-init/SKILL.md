---
name: skill-lab-init
description: One-time setup for skill-lab test infrastructure
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, Grep, AskUserQuestion
---

# Skill Lab Init

One-time setup. Asks about the skill being tested, scaffolds the harness, writes config.

## Guard

If `harness/` already exists, tell the user:
- "Test harness already exists. Run `/skill-lab-upgrade` to update it, or delete `harness/` to start fresh."
- Stop here.

## Conversation Style

**One decision at a time.** Present one question, get the answer, move to the next.

**Multiple choice with recommendations.** Give options with your recommendation first. The user is the decision-maker.

## Phase 1 — Understand the Skill

Ask the user these questions, one at a time:

1. **What does the skill do?** Get a plain description of the skill's purpose and output.

2. **What type of skill is it?**
   - **Interactive** — the skill has the agent collaborate with a human counterpart (PM, reviewer, user). Two agents needed: skill tester follows the skill, evaluator plays the counterpart.
   - **Autonomous** — the skill has the agent work alone and produce output. One agent needed, evaluator grades output post-hoc.
   - **Orchestration** — the skill has the agent coordinate multiple sub-agents. Skill tester in test mode, team lead proxies spawn requests.

3. **Where is the skill?** Get the path to the skill's SKILL.md file. Verify the file exists.

4. **What does good look like?** What should a successful run produce?

5. **What does bad look like?** What are you worried might go wrong?

**Skill types affect test configuration:**

| Type | Agents | Evaluator Mode | Team Lead Role |
|------|--------|----------------|----------------|
| Interactive | Skill Tester + Evaluator | Interactive (plays counterpart) | Passive monitor |
| Autonomous | Skill Tester only | Post-hoc (grades output) | Passive monitor, spawns evaluator after |
| Orchestration | Skill Tester + dynamic agents | Post-hoc (grades output + coordination) | Active: handles spawn requests |

## Phase 2 — Scaffold

Run the init-harness script:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/init-harness.sh
```

Explain the created structure to the user.

Ask about fixture needs:
- **Mock server** — the skill needs a fake API, service, or external system
- **Sample files** — the skill needs input files (documents, configs, data)
- **None** — the skill works with just the skill definition and an evaluator

If fixtures are needed, guide the user to create `start-fixture.sh` and `stop-fixture.sh` in the scenario directory. `start-fixture.sh` receives the experiment path as an argument and should write any runtime variables (URLs, ports, PIDs) to `$EXPERIMENT_PATH/fixture/.fixture-env` as `KEY=VALUE` pairs. These become available as `{{KEY}}` in prompt templates.

**If the skill type is orchestration**, copy the spawning protocol briefing into the harness:

```bash
cp ${CLAUDE_PLUGIN_ROOT}/templates/spawning-protocol-briefing.md harness/
```

This enables the subagent spawning protocol in the skill tester's prompt. `setup.sh` copies `harness/*-briefing.md` files into each experiment's fixture directory, where `render-prompt.sh` auto-discovers them.

## Phase 3 — Write Config

Write `harness/config.yml` using the answers from Phase 1:

```yaml
skill_lab:
  version: "0.2.0"
  initialized: "{today's date, YYYY-MM-DD}"

skill:
  name: {skill name, derived from SKILL.md frontmatter or user's description}
  path: {path to SKILL.md}
  type: {interactive | autonomous | orchestration}
  description: "{user's answer to question 1}"
  success_criteria: "{user's answer to question 4}"
  failure_concerns: "{user's answer to question 5}"
```

## Phase 4 — Write Harness CLAUDE.md

Write `harness/CLAUDE.md` with:

```markdown
# Test Harness

Test infrastructure for the **{skill name}** skill (`{skill path}`).

## What This Is

This harness tests the skill through controlled experiments with agent teams. Scenarios define traps with known ground truth; evaluator agents grade the skill tester's performance against a rubric.

## Skill Under Test

- **Name:** {skill name}
- **Type:** {skill type}
- **Description:** {skill description}
- **Success criteria:** {success criteria}
- **Failure concerns:** {failure concerns}

## Running Experiments

1. `bash harness/scripts/setup.sh <scenario>` — prepare an experiment from a scenario
2. Use `/skill-lab-experiment <scenario>` to run a full experiment with agent teams
3. Results go to `experiments/YYYYMMDD-HHMM/output/`
4. Experiment logs go to `docs/experiment-log/`

## Structure

- `harness/scripts/` — setup, teardown, prompt rendering
- `harness/subagents/` — prompt templates for skill-tester and evaluator-agent
- `harness/scenarios/` — test scenarios with traps and evaluator briefings
- `harness/config.yml` — configuration written by skill-lab-init
- `experiments/` — experiment output (agent-generated, ephemeral)
- `docs/experiment-log/` — experiment log entries (version-controlled)

## Trust Boundaries

- `harness/` is trusted (human-authored, version-controlled)
- `experiments/` is untrusted (agent-generated). Never place a CLAUDE.md there.
```

Fill in all `{placeholders}` with actual values from the user's answers.

## Wrap Up

Tell the user what was created. Suggest: "Run `/skill-lab-add-scenario` to design your first test scenario."
