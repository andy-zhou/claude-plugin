---
name: skill-lab-upgrade
description: Sync templates and apply migrations from the latest plugin version
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, Grep, AskUserQuestion
---

# Skill Lab Upgrade

Sync templates from the latest plugin version, apply structural migrations, write changelog, update config.

## Guard

If `harness/` does not exist, tell the user: "No test harness found. Run `/skill-lab-init` first." Stop here.

If `harness/config.yml` does not exist, tell the user: "Harness exists but is missing config. Run `/skill-lab-init` to complete setup." Stop here.

## Conversation Style

**One decision at a time.** Show each diff, get approval, then move to the next.

**Recommend but don't force.** The user may have customized templates. Always show what would change.

## Version Check

Read installed version from `harness/config.yml` (`skill_lab.version`).

Read current plugin version from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` (`version`).

If versions match: "Harness is up to date (v{version}). No changes needed." Stop here.

Display: "Harness is at v{installed}. Plugin is at v{current}. Checking for updates..."

## Template Sync

Compare template files between the plugin source and the harness:

### Scripts
For each file in `${CLAUDE_PLUGIN_ROOT}/templates/scripts/`:
- Compare against `harness/scripts/{filename}`
- If different: show the diff, ask the user whether to apply the update

### Subagent Templates
For each file in `${CLAUDE_PLUGIN_ROOT}/templates/subagents/`:
- Compare against `harness/subagents/{filename}`
- If different: show the diff, ask the user whether to apply the update

### New Files
Check for files in the plugin templates that don't exist in the harness:
- New script files → offer to copy to `harness/scripts/`
- New subagent templates → offer to copy to `harness/subagents/`
- New briefing files → offer to copy to `harness/`

For each difference, present one at a time with a recommendation (usually "apply" unless the user has clearly customized the file).

## Structural Migration

Check for structural changes between versions:
- New directories that should exist
- Renamed files or directories
- Config schema changes (new fields, renamed fields)

Apply structural changes:
- Create new directories
- Move files if renamed
- Add new config fields with sensible defaults (show the user what's being added)

## Changelog

Create or append to `harness/CHANGELOG.md`:

```markdown
## [{new-version}] - {YYYY-MM-DD}

- {List each change applied: template updated, file added, structure changed}
```

If the file doesn't exist, create it with a header:

```markdown
# Changelog

All notable changes to this test harness.

## [{new-version}] - {YYYY-MM-DD}

- {changes}
```

## Update Config and CLAUDE.md

Update `harness/config.yml`:
- Set `skill_lab.version` to the new plugin version

Regenerate `harness/CLAUDE.md`:
- Read current config values
- Rewrite using the same template structure as `skill-lab-init` with current values

## Report

Summarize what was updated:
- Number of template files updated
- Structural changes applied
- New version number
- Changelog entry path
