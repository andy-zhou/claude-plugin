# Design: Migrate subagent-analysis to Agent Teams

**Status:** Implemented

> **Note:** Step names and numbers in this document reflect the pre-rubric-hardening
> workflow. See `2026-02-08-sign-off-rubrics-design.md` for the subsequent renumbering
> that introduced Step 5 (Rubric Hardening) and shifted later steps.

## Summary

Update the subagent-analysis skill to use Claude Code's experimental agent teams feature instead of Task-tool subagents. Add an inter-persona debate phase where teammates challenge each other's findings before synthesis.

## Changes

### SKILL.md — 8 steps become 9

Steps 1-4 unchanged (scope, clarify, select, align).

- **Step 5**: Create agent team — spawn one teammate per persona with lead in delegate mode
- **Step 6**: Collect reviews — teammates write review files, lead validates schema
- **Step 7 (NEW)**: Debate — teammates read each other's reviews, challenge findings via direct messaging, optionally update their reviews with a Debate Notes section
- **Step 8**: Synthesize — incorporates debate outcomes; conflicts tagged with resolution-source (debate, domain-authority, escalated)
- **Step 9**: Act — present summary, commit, clean up agent team

Additional:
- Prerequisites section: check for `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var
- Fallback: if agent teams unavailable, fall back to Task-tool subagent dispatch (no debate phase)
- Updated Common Mistakes table with agent-team pitfalls

### analysis-schema.md

Per-persona review format gains:
- `## Debate Notes` section (required after debate, even if "No challenges received")

Synthesis format gains:
- `Resolution-source` field on each conflict: `debate | domain-authority | escalated`

### README.md

- Note that the skill uses agent teams (experimental) with Task-tool fallback

## Files to modify

1. `skills/subagent-analysis/SKILL.md`
2. `skills/subagent-analysis/analysis-schema.md`
3. `README.md`
