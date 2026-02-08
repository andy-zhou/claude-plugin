# andys-skills

A Claude Code plugin hosting custom skills. Each skill lives under `skills/{skill-name}/` with its own `SKILL.md` and supporting files.

## Current Skills

- **subagent-analysis** — Brainstorms context-specific reviewer personas with the user, dispatches them as parallel teammates, facilitates inter-persona debate, and synthesizes findings with debate-first conflict resolution. Uses Claude Code agent teams (experimental) with Task-tool subagent fallback.

## File Structure

```
andys-skills/
├── .claude-plugin/
│   └── plugin.json                # Plugin manifest for Claude Code discovery
├── package.json                   # Node metadata (private, no deps)
├── CLAUDE.md                      # Session instructions for Claude Code
├── docs/
│   ├── implementation-plan.md     # Historical: original build plan (archived)
│   └── plans/
│       └── 2026-02-08-agent-teams-migration-design.md
└── skills/
    └── subagent-analysis/
        ├── SKILL.md               # Main skill: 8-step review workflow (agent teams + debate)
        ├── analysis-schema.md     # Output schema for reviews + synthesis
        └── personas/
            └── examples/          # Reference persona templates (not used directly)
                ├── security-engineer.md
                ├── principal-engineer.md
                └── reliability-engineer.md
```

## Modifying or Adding Skills

Use the `superpowers:writing-skills` skill before editing any `SKILL.md`, persona template, or schema file. It enforces a TDD process for skill changes: define the failing case first, make the edit, then verify.

To add a new skill, create `skills/{skill-name}/SKILL.md` following the structure documented in `writing-skills`. Supporting files (schemas, templates, reference material) live alongside the `SKILL.md` in the same directory.
