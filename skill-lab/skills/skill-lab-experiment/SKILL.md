---
name: skill-lab-experiment
description: Run an experiment with agent teams in an isolated worktree
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, Grep, Task, AskUserQuestion, TeamCreate, TeamDelete, SendMessage, TaskCreate, TaskUpdate, TaskList, TaskGet
---

# Skill Lab Experiment

Run a full experiment: create a worktree, set up the scenario, spawn agent teams, monitor, shut down, record results, merge back.

**Arguments:** Optional scenario name (e.g., `/skill-lab-experiment freight-flow`).

## Guards

If `harness/` does not exist, tell the user: "No test harness found. Run `/skill-lab-init` first." Stop here.

If `harness/config.yml` does not exist, tell the user: "Harness is missing config. Run `/skill-lab-init` to complete setup." Stop here.

If no directories exist in `harness/scenarios/`, tell the user: "No scenarios found. Run `/skill-lab-add-scenario` to design one." Stop here.

## Scenario Selection

- If a scenario name was provided as an argument, use it. Verify `harness/scenarios/<name>/` exists.
- If only one scenario exists, auto-select it.
- Otherwise, list available scenarios and ask the user to pick.

## Read Config

Read `harness/config.yml` for:
- `skill.type` — determines agent spawning strategy (interactive / autonomous / orchestration)
- `skill.name` — for display and commit messages

---

## Worktree Lifecycle

### Create Worktree

```bash
git worktree add .skill-lab-worktree -b skill-lab-exp-$(date +%Y%m%d-%H%M)
```

All experiment work happens in the worktree. Change working directory to the worktree for subsequent commands.

### Setup

In the worktree:

```bash
bash harness/scripts/setup.sh <scenario-name>
```

Validate:
1. Check the experiment directory was created under `experiments/`
2. Read the rendered prompts in `fixture/` to verify variable substitution worked
3. Show the user the rendered skill-tester and evaluator prompts

Determine the experiment path (the `experiments/YYYYMMDD-HHMM/` directory created by setup.sh).

---

## Run the Experiment

### Interactive Skills

Create a team. Spawn two agents with rendered prompts from `{experiment-path}/fixture/`:

1. **skill-tester** — prompt from `fixture/skill-tester-prompt.md`, `mode: bypassPermissions`
2. **evaluator-agent** — prompt from `fixture/evaluator-agent-prompt.md`, `mode: bypassPermissions`

Both communicate via SendMessage. The evaluator plays the counterpart role and grades during conversation.

### Autonomous Skills

Create a team. Spawn one agent:

1. **skill-tester** — prompt from `fixture/skill-tester-prompt.md`, `mode: bypassPermissions`

After the skill tester finishes, spawn the evaluator:

2. **evaluator-agent** — prompt from `fixture/evaluator-agent-prompt.md`, `mode: bypassPermissions`

The evaluator reads output files and grades post-hoc.

### Orchestration Skills

Create a team. Spawn:

1. **skill-tester** — prompt from `fixture/skill-tester-prompt.md`, `mode: bypassPermissions`

Handle subagent lifecycle messages from the skill tester:

**When the skill tester sends a `spawn_request`:**
1. Parse `name` and `prompt_file` from the JSON message.
2. Namespace the name with `sub-` prefix (e.g., `billing` -> `sub-billing`). Prevents collisions with `skill-tester`, `evaluator-agent`, and `team-lead`.
3. Reject duplicates. If `sub-{name}` is already active, respond:
   ```json
   {"type": "spawn_response", "name": "billing", "status": "error", "reason": "sub-billing is already active"}
   ```
4. Read the prompt from `prompt_file`.
5. Spawn the subagent with the Task tool: `mode: bypassPermissions`, `team_name` set to the current team, namespaced name.
6. Send `spawn_response` to the skill tester:
   ```json
   {"type": "spawn_response", "name": "sub-billing", "status": "spawned"}
   ```

**When the skill tester sends a `terminate_request`:**
1. Send `shutdown_request` (built-in SendMessage type) to the named subagent.
2. Wait for acknowledgment.
3. Send `terminate_response` to the skill tester:
   ```json
   {"type": "terminate_response", "name": "sub-billing", "status": "terminated"}
   ```

After the skill tester finishes, spawn the evaluator to grade output + coordination quality.

---

## Monitoring (All Types)

- Watch for idle notifications — agents go idle between every message exchange; this is normal.
- Use Glob or `ls` to check output files periodically.
- Do NOT use `sleep` or polling loops — they block the session.
- Do not steer the skill tester — observe what it does naturally.
- Nudge only if an agent seems stuck (3+ rapid idles with no progress).

## Shutdown Order

1. Wait for the skill tester to finish — it must be idle with no pending work. If spawning is enabled, the skill tester must also terminate its own subagents before finishing (no active subagents remaining).
2. If the evaluator hasn't written `output/logs/evaluator-report.md`, nudge it via SendMessage.
3. Send `shutdown_request` to the evaluator, then to the skill tester.
4. If the skill tester resumes work after a shutdown request, let it finish.
5. Delete the team.

## Teardown

```bash
bash harness/scripts/teardown.sh
```

---

## Record Results

### Determine Experiment Number

Check `docs/experiment-log/` for existing entries. The next experiment is N+1.

### Create Experiment Log

Create `docs/experiment-log/experiment-{N}.md` using the template at `${CLAUDE_PLUGIN_ROOT}/templates/experiment-log/experiment-template.md`.

Fill in:
- Date (today)
- Scenario name
- Rubric scores from the evaluator report (`output/logs/evaluator-report.md`)
- Notable observations from the conversation log

### Update README

Add a row to `docs/experiment-log/README.md` with experiment number, date, scenario, score, and link.

### Commit in Worktree

```bash
git add experiments/ docs/experiment-log/ && git commit -m "Experiment {N}: {scenario} — {score}"
```

---

## Merge and Cleanup

Switch back to the original branch directory:

```bash
ORIGINAL_DIR=$(cd .. && pwd)  # or wherever the original repo is
cd {original-repo-path}
git merge skill-lab-exp-YYYYMMDD-HHMM
git worktree remove .skill-lab-worktree
```

---

## Report to User

Present:
1. **Rubric scorecard** — the evaluator's scores for each trap
2. **Notable observations** — interesting behaviors from the conversation log
3. **Experiment log path** — where the full log entry was written

Reference `${CLAUDE_PLUGIN_ROOT}/guides/analysis-playbook.md` for how to analyze results and decide on next steps.

Suggest next actions:
- Analyze results and make skill edits in normal conversation
- `/skill-lab-experiment` to run another experiment after making changes
- `/skill-lab-add-scenario` to test generalization with a new scenario
