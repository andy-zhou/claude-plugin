# andys-skills

A Claude Code plugin hosting custom skills. Each skill lives under `skills/{skill-name}/` with its own `SKILL.md` and supporting files.

## Current Skills

- **subagent-analysis** — Dispatches parallel expert-persona subagents (security engineer, principal engineer, reliability engineer) to review a technical artifact, then synthesizes findings with domain-authority conflict resolution.

## File Structure

```
andys-skills/
├── .claude-plugin/
│   └── plugin.json                # Plugin manifest for Claude Code discovery
├── package.json                   # Node metadata (private, no deps)
├── CLAUDE.md                      # Session instructions for Claude Code
├── docs/
│   └── implementation-plan.md     # Historical: original build plan (archived)
└── skills/
    └── subagent-analysis/
        ├── SKILL.md               # Main skill: 8-step review workflow
        ├── analysis-schema.md     # Output schema for reviews + synthesis
        └── personas/
            ├── security-engineer.md
            ├── principal-engineer.md
            └── reliability-engineer.md
```

## Modifying or Adding Skills

Use the `superpowers:writing-skills` skill before editing any `SKILL.md`, persona template, or schema file. It enforces a TDD process for skill changes: define the failing case first, make the edit, then verify.

To add a new skill, create `skills/{skill-name}/SKILL.md` following the structure documented in `writing-skills`. Supporting files (schemas, templates, reference material) live alongside the `SKILL.md` in the same directory.
