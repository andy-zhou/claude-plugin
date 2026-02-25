---
name: skill-lab-add-scenario
description: Design a test scenario with traps, rubric, and evaluator briefing
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, Grep, AskUserQuestion
---

# Skill Lab Add Scenario

Design a test scenario for the skill under test. Guides through domain selection, trap design, rubric creation, and evaluator briefing.

## Guard

If `harness/` does not exist, tell the user: "No test harness found. Run `/skill-lab-init` first." Stop here.

If `harness/config.yml` does not exist, tell the user: "Harness is missing config. Run `/skill-lab-init` to complete setup." Stop here.

## Conversation Style

**One decision at a time.** Present one question, get the answer, move to the next.

**Multiple choice with recommendations.** Give options with your recommendation first. The user is the decision-maker.

## Setup

Read `harness/config.yml` to understand the skill being tested:
- Skill type (interactive / autonomous / orchestration) — affects evaluator mode and trap design
- Description — what the skill does
- Failure concerns — what to target with traps

Reference `${CLAUDE_PLUGIN_ROOT}/guides/scenario-design.md` for principles throughout this process.

## Step 1 — Domain and Context

Guide the user through choosing a test domain:

- The domain should be **parallel to the skill's real target**, not the same one. This tests generalization.
- The context should feel **realistically messy** — built over years by different teams, not a clean textbook example.
- Ask the user what domain they want to use, or propose 2-3 options with a recommendation.

## Step 2 — Trap Design

Design 5-8 traps with ground truth. For each trap:

1. **What it tests** — which skill behavior is being exercised
2. **The setup** — what the scenario presents to the skill tester
3. **Ground truth** — the correct answer or behavior
4. **Caught / Partial / Missed** — clear, objective criteria for each grade

Choose trap categories appropriate to the skill type:
- **Interactive:** Focus on discovery and questioning behavior
- **Autonomous:** Focus on output correctness and completeness
- **Orchestration:** Include delegation and coordination traps

Work through traps one at a time with the user. For each trap, present the design and get confirmation before moving to the next.

## Step 3 — Target Task

Define the work that forces the skill tester through the traps:

- The task should be something the skill naturally handles
- It must lead the agent through areas where traps exist
- It should feel like a real request, not an obvious test

## Step 4 — Grading Criteria

Compile the rubric — one item per trap with:
- Clear triggering behaviors (what specifically would the agent do or say)
- Independence (catching one trap doesn't require catching another)
- Tests the skill's instructions, not general intelligence

## Step 5 — Evaluator Mode

Ask about evaluator mode (informed by skill type from config):

- **Interactive counterpart** — the evaluator plays a role during the test (PM, reviewer, user) and grades based on the conversation. Best for interactive skills.
- **Post-hoc grading** — the evaluator reads output files after the test and grades against the rubric. Best for autonomous skills.
- **Both** — interactive during the test, then writes a comprehensive post-hoc evaluation. Best when you want rich conversational data and structured grades.

Recommend based on skill type:
- Interactive → interactive counterpart or both
- Autonomous → post-hoc grading
- Orchestration → post-hoc grading (grades output + coordination)

## Step 6 — Write Scenario Files

Create the scenario directory and write files to `harness/scenarios/<name>/`:

### `evaluator-briefing.md` (required)

Include:
1. **Role description** — who the evaluator is pretending to be (if interactive)
2. **Ground truth** — the correct answers for each trap
3. **Rubric** — caught/partial/missed criteria for each trap with clear triggering behaviors
4. **Behavior rules** — how to interact with the skill tester (if interactive): what to reveal when asked, what to withhold, how to respond to wrong conclusions

### `skill-tester-context-briefing.md` (required)

The target task and domain context for the skill tester. This is what the skill tester sees as its assignment — it should read like a real user request, not an obvious test. Include:
1. **Task description** — the work from Step 3 that drives the skill tester through the traps
2. **Domain context** — enough background for the task to feel realistic
3. **Any scenario-specific inputs** — file paths, API details, constraints the skill tester needs to know

### Additional fixture files

As needed by the scenario:
- API descriptions, data files, configs
- Mock server scripts (`start-fixture.sh`, `stop-fixture.sh`) if the scenario needs a running service
- Any other files the skill tester will need

## Wrap Up

Summarize what was created:
- Scenario name and domain
- Number of traps and their categories
- Evaluator mode

Suggest: "Run `/skill-lab-experiment {scenario-name}` to run the first experiment."
