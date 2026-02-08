Read `README.md` for project overview and file structure.

This is a multi-skill Claude Code plugin repo. Each skill lives under `skills/{skill-name}/` with its own `SKILL.md` and supporting files.

## Architecture: subagent-analysis

The `subagent-analysis` skill brainstorms context-specific reviewer personas with the user, dispatches them as parallel teammates, facilitates debate, and synthesizes findings:

- `SKILL.md` orchestrates the 8-step workflow (scope, brainstorm personas, align, dispatch, validate, debate, synthesize, act)
- Personas are generated dynamically based on the artifact and user concerns — not selected from a fixed list
- Example persona templates in `personas/examples/` show the expected structure and depth for reference
- `analysis-schema.md` enforces a consistent output format across all personas and the synthesis document

## Conventions

- Each skill lives in `skills/{skill-name}/` with its own `SKILL.md`
- subagent-analysis output goes to `.subagent-analysis/{topic}/{run-id}/` in whichever repo the skill is invoked from (run-id is a `YYYYMMDD-HHMMSS` timestamp)
- Persona reviews use YAML frontmatter with sign-off (`approve | conditional-approve | reject`) and confidence levels
- Conflicts are resolved debate-first; scope-based authority is the fallback when debate doesn't converge

## Modifying or Creating Skills

Use the `superpowers:writing-skills` skill before editing any `SKILL.md`, persona template, or schema file. It enforces TDD for skill changes: define the failing case first, make the edit, then verify. Do not skip this — untested skill edits tend to introduce subtle regressions in agent behavior.

## Stewardship

When adding a new skill, removing a skill, or changing the file structure, update `README.md` to reflect the change. The README is the first thing a future session reads — if it's wrong, everything downstream is wrong. At minimum, update the "Current Skills" list and the file structure tree.

## Historical Context

`docs/implementation-plan.md` is the original build plan from initial development. It is archived and should not be treated as a live spec.
