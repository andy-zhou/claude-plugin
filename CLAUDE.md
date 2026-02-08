Read `docs/implementation-plan.md` at the start of every session. It contains the full implementation plan, design decisions, and file-by-file content specifications for this plugin.

This is a Claude Code plugin that provides a `subagent-analysis` skill for multi-persona expert review with structured output and synthesis.

## Project State

Phase 1 (scaffolding) is complete:
- `.claude-plugin/plugin.json` — plugin manifest
- `package.json` — node metadata (private, no deps)
- `skills/subagent-analysis/personas/` — empty directory awaiting persona files
- Git initialized with initial commit

Phases 2–4 remain: schema, personas, main skill file. See `docs/implementation-plan.md` for exact content.

## Conventions

- This plugin lives at `~/workspace/subagent-analysis/` and is a standalone git repo.
- It is designed to be used alongside the Kani project at `~/workspace/kani/`. The Kani tech spec (`~/workspace/kani/docs/plans/2026-02-07-kani-tech-spec.md`) is the primary test artifact for validation.
- Output from running the skill goes to `.subagent-analysis/{topic}/{persona-name}.md` in whichever repo the skill is invoked from.
- Commit each phase as a separate commit.
