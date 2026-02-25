#!/usr/bin/env bash
# Render a subagent prompt template with experiment-specific values.
#
# Phase 1 (file content substitution): Any file matching *-briefing.md in the
# fixture dir becomes a {{*_BRIEFING}} variable. E.g., evaluator-briefing.md
# becomes {{EVALUATOR_BRIEFING}}. Uppercased, hyphens to underscores.
#
# Phase 1c (config substitution): Reads config.yml and maps section.key entries
# to {{SECTION_KEY}} placeholders. E.g., skill.path -> {{SKILL_PATH}}.
#
# Phase 2 (string substitution): Standard vars (OUTPUT_DIR, EXPERIMENT_DIR,
# FIXTURE_DIR, SPAWN_DIR) plus any KEY=VALUE pairs from .fixture-env.
# Env vars override hardcoded defaults.
#
# Phase 3 (env var sweep): Any remaining {{VAR}} patterns are replaced with
# matching env vars. Unreplaced embedded patterns trigger a warning.
#
# Phase 4 (cleanup): Standalone placeholders (alone on a line) are optional
# injection points. Any still unreplaced after all phases are removed silently.
#
# Usage: render-prompt.sh <agent-name> <experiment-name>
# Example: render-prompt.sh skill-tester 20260224-1430

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: render-prompt.sh <agent-name> <experiment-name>" >&2
    exit 1
fi

AGENT="$1"
EXPERIMENT_NAME="$2"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$HARNESS_DIR")"

TEMPLATE="$HARNESS_DIR/subagents/${AGENT}.md"
EXPERIMENT_PATH="$PROJECT_DIR/experiments/$EXPERIMENT_NAME"
FIXTURE_DIR="$EXPERIMENT_PATH/fixture"

if [[ ! -f "$TEMPLATE" ]]; then
    echo "Error: Template not found: $TEMPLATE" >&2
    echo "Available templates:" >&2
    ls "$HARNESS_DIR/subagents/"*.md 2>/dev/null | while read f; do
        echo "  $(basename "$f" .md)" >&2
    done
    exit 1
fi

# Use Python for multi-line file content substitution and auto-discovery
python3 - "$TEMPLATE" "$FIXTURE_DIR" "$EXPERIMENT_PATH" <<'PYEOF'
import sys
import os
import re

template_path, fixture_dir, experiment_path = sys.argv[1:4]

with open(template_path) as f:
    template = f.read()

# --- Phase 1: File content substitution (auto-discovered) ---
# Any file matching *-briefing.md becomes {{*_BRIEFING}}
if os.path.isdir(fixture_dir):
    for filename in os.listdir(fixture_dir):
        if filename.endswith("-briefing.md"):
            # evaluator-briefing.md -> EVALUATOR_BRIEFING
            var_name = filename.replace("-briefing.md", "")
            var_name = var_name.upper().replace("-", "_") + "_BRIEFING"
            placeholder = "{{" + var_name + "}}"
            if placeholder in template:
                filepath = os.path.join(fixture_dir, filename)
                try:
                    with open(filepath) as f:
                        content = f.read().rstrip("\n")
                    template = template.replace(placeholder, content)
                except FileNotFoundError:
                    print(f"Warning: File not found for {placeholder}: {filepath}", file=sys.stderr)

# --- Phase 1b: Clear unfound briefing placeholders ---
# Any {{*_BRIEFING}} still in the template has no matching file — replace with
# empty string silently. This makes briefing-based features optional: if the
# file exists it's injected, if not the placeholder disappears.
template = re.sub(r'\{\{\w+_BRIEFING\}\}\n?', '', template)

# --- Phase 1c: Config file substitution ---
# Read config.yml for skill-level variables (e.g., skill.path -> {{SKILL_PATH}}).
harness_dir = os.path.dirname(os.path.dirname(template_path))
config_path = os.path.join(harness_dir, "config.yml")
if os.path.isfile(config_path):
    with open(config_path) as f:
        section = None
        for line in f:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if not line[0].isspace() and stripped.endswith(":"):
                section = stripped[:-1]
            elif section and line[0].isspace():
                m = re.match(r'\s+(\w+):\s*(.*)', line)
                if m:
                    key = (section + "_" + m.group(1)).upper()
                    value = m.group(2).strip().strip('"').strip("'")
                    placeholder = "{{" + key + "}}"
                    if placeholder in template:
                        template = template.replace(placeholder, value)

# --- Phase 2: String substitution ---
# Env vars override hardcoded defaults
template = template.replace("{{OUTPUT_DIR}}", os.environ.get("OUTPUT_DIR", os.path.join(experiment_path, "output")))
template = template.replace("{{EXPERIMENT_DIR}}", os.environ.get("EXPERIMENT_DIR", experiment_path))
template = template.replace("{{FIXTURE_DIR}}", os.environ.get("FIXTURE_DIR", fixture_dir))
template = template.replace("{{SPAWN_DIR}}", os.environ.get("SPAWN_DIR", os.path.join(experiment_path, "spawn")))

# Load .fixture-env if present (KEY=VALUE pairs)
fixture_env = os.path.join(fixture_dir, ".fixture-env")
if os.path.isfile(fixture_env):
    with open(fixture_env) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                placeholder = "{{" + key + "}}"
                template = template.replace(placeholder, value)

# --- Phase 3: Env var sweep ---
# Replace remaining {{VAR}} patterns with matching env vars.
# Standalone placeholders (alone on a line) are optional — suppress warnings for
# those since Phase 4 will clean them up.
standalone_vars = set(re.findall(r'^\s*\{\{(\w+)\}\}\s*$', template, flags=re.MULTILINE))

def env_replace(match):
    name = match.group(1)
    value = os.environ.get(name)
    if value is not None:
        return value
    if name not in standalone_vars:
        print(f"Warning: unreplaced variable {{{{{name}}}}} (no env var '{name}' set)", file=sys.stderr)
    return match.group(0)

template = re.sub(r'\{\{(\w+)\}\}', env_replace, template)

# --- Phase 4: Clear standalone optional placeholders ---
# Placeholders alone on a line are optional injection points (e.g., {{SKILL_TESTER_CONTEXT}}).
# If still present after all substitution phases, remove the line.
template = re.sub(r'^\s*\{\{\w+\}\}\s*\n', '', template, flags=re.MULTILINE)

print(template)
PYEOF
