# skill-lab README Design

**Date:** 2026-02-27
**Status:** Approved

## Goal

Add a README.md to the skill-lab plugin root that serves both new users (onboarding) and experienced skill authors (reference).

## Framing

"Evals-driven development for Claude Code skills" — the skill-lab helps you iteratively improve skills by running controlled experiments with agent teams and structured evaluations.

## Approach

Workflow-first narrative: teach the mental model, then give reference. Concise (~150-250 lines) with links to the existing deep-dive guides.

## Sections

### 1. Header + What is skill-lab
- 3-4 sentences: evals-driven development concept, iterative loop, agent-based experiments
- Position: top of README

### 2. Workflow overview
- The 4-step loop: init → design scenarios → run experiments → analyze & iterate
- Each step: 2-3 sentences, slash command named inline
- Communicates the mental model before diving into commands

### 3. Commands quick reference
- Table: command | purpose
- 5 commands: `/skill-lab`, `/skill-lab-init`, `/skill-lab-add-scenario`, `/skill-lab-experiment`, `/skill-lab-upgrade`

### 4. Key concepts
- 2-3 sentences each: harness, scenarios (traps + rubrics + fixtures), skill types (interactive/autonomous/orchestration), experiment lifecycle (worktree → setup → agents → teardown → log)

### 5. Deep dives (links)
- `guides/scenario-design.md` — trap categories, rubric design, anti-patterns
- `guides/analysis-playbook.md` — diagnosing failures, overfitting watch, fix proposals

### 6. Harness directory structure
- File tree showing what `/skill-lab-init` creates
- Helps users understand the layout before they run init

## Non-goals

- Not a tutorial with a worked example (that could come later)
- Not a replacement for the guides — the README links to them
- No changes to existing SKILL.md files or guides
