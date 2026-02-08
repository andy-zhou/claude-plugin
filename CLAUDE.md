Read `README.md` for project overview and file structure.

This is a multi-skill Claude Code plugin repo. Each skill lives under `skills/{skill-name}/` with its own `SKILL.md` and supporting files.

## Architecture: subagent-analysis

The `subagent-analysis` skill dispatches parallel expert-persona subagents to review technical artifacts:

- `SKILL.md` orchestrates the 8-step workflow (scope, clarify, select, align, dispatch, validate, synthesize, act)
- Persona templates in `personas/` define each reviewer's lens, scope boundaries, and analytical questions
- `analysis-schema.md` enforces a consistent output format across all personas and the synthesis document

## Conventions

- Each skill lives in `skills/{skill-name}/` with its own `SKILL.md`
- subagent-analysis output goes to `.subagent-analysis/{topic}/` in whichever repo the skill is invoked from
- Persona reviews use YAML frontmatter with sign-off (`approve | conditional-approve | reject`) and confidence levels
- Synthesis uses domain-authority conflict resolution, not majority vote — the persona whose scope covers the disputed topic has authority

## Modifying or Creating Skills

Use the `superpowers:writing-skills` skill before editing any `SKILL.md`, persona template, or schema file. It enforces TDD for skill changes: define the failing case first, make the edit, then verify. Do not skip this — untested skill edits tend to introduce subtle regressions in agent behavior.

## Adding Personas (subagent-analysis)

1. Create a new `.md` file in `skills/subagent-analysis/personas/` following the existing template structure (Scope, Analytical Lens, Review Instructions, Output Requirements)
2. Update the persona selection table in `skills/subagent-analysis/SKILL.md` (Step 3)
3. Update the conflict resolution domain-authority table in SKILL.md (Step 7) if the new persona introduces new authority domains

## Stewardship

When adding a new skill, removing a skill, or changing the file structure, update `README.md` to reflect the change. The README is the first thing a future session reads — if it's wrong, everything downstream is wrong. At minimum, update the "Current Skills" list and the file structure tree.

## Historical Context

`docs/implementation-plan.md` is the original build plan from initial development. It is archived and should not be treated as a live spec.
