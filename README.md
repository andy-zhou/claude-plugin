# andys-skills

A Claude Code plugin hosting custom skills. Each skill lives under `skills/{skill-name}/` with its own `SKILL.md` and supporting files.

## Current Skills

- **subagent-analysis** — Brainstorms context-specific reviewer personas with the user, dispatches them as parallel teammates, facilitates inter-persona debate, and synthesizes findings with debate-first conflict resolution. Uses Claude Code agent teams (experimental) with Task-tool subagent fallback.

## Installation

Clone the repo, then register it as a Claude Code plugin marketplace:

```bash
git clone <repo-url> ~/workspace/andys-skills
```

In any Claude Code session:

```
/plugin marketplace add ~/workspace/andys-skills
/plugin install subagent-analysis@andys-skills
```

The `subagent-analysis` skill requires agent teams (experimental). Enable it by adding the following to your project's `.claude/settings.json` (or `~/.claude/settings.json` for global config):

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Without agent teams enabled, the skill falls back to Task-tool subagent dispatch (no debate phase).

## Usage

```
/subagent-analysis path/to/my-spec.md
```

After invocation, the skill will ask you 1-5 questions to shape the review
personas (or you can say "just go" to skip). Once you confirm the personas,
expert reviewers are dispatched in parallel. If agent teams are enabled, the
reviewers then debate each other's findings. Finally, a synthesis document
summarizes all findings, conflicts, and prioritized recommendations.

Output is written to `.subagent-analysis/{topic}/{run-id}/` in your project
directory, with one file per reviewer plus a `synthesis.md`.

## File Structure

```
andys-skills/
├── .claude-plugin/
│   ├── plugin.json                # Plugin manifest for Claude Code discovery
│   └── marketplace.json           # Marketplace definition for plugin installation
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

# Runtime output (in the project where the skill is invoked):
# .subagent-analysis/{topic}/{run-id}/
# ├── {persona-name}.md            # One review per persona
# └── synthesis.md                 # Combined findings and recommendations
```

## Modifying or Adding Skills

Use the `superpowers:writing-skills` skill before editing any `SKILL.md`, persona template, or schema file. It enforces a TDD process for skill changes: define the failing case first, make the edit, then verify.

To add a new skill, create `skills/{skill-name}/SKILL.md` following the structure documented in `writing-skills`. Supporting files (schemas, templates, reference material) live alongside the `SKILL.md` in the same directory.
