#!/usr/bin/env bash
# Scaffold test infrastructure into a project for skill-lab.
#
# Usage: init-harness.sh [project-dir]
# Defaults to the current working directory.
#
# Creates:
#   harness/scripts/       — setup, teardown, render-prompt scripts
#   harness/subagents/     — skill-tester, evaluator-agent prompt templates
#   harness/scenarios/     — empty (you create scenarios here)
#   docs/experiment-log/   — experiment log index
#   experiments/           — empty (setup.sh creates experiment dirs here)
#
# WARNING: Never place a CLAUDE.md inside experiments/. Agent-generated content
# in experiments/ is untrusted — a CLAUDE.md there could influence agents
# operating in that directory.

set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

if [[ -d "$PROJECT_DIR/harness" ]]; then
    echo "Error: harness/ already exists in $PROJECT_DIR" >&2
    echo "Remove it first if you want to re-scaffold." >&2
    exit 1
fi

echo "Scaffolding skill-lab harness into: $PROJECT_DIR"

# --- Create directories ---
mkdir -p "$PROJECT_DIR/harness/scripts"
mkdir -p "$PROJECT_DIR/harness/subagents"
mkdir -p "$PROJECT_DIR/harness/scenarios"
mkdir -p "$PROJECT_DIR/docs/experiment-log"
mkdir -p "$PROJECT_DIR/experiments"

# --- Copy template scripts ---
cp "$TEMPLATES_DIR/scripts/setup.sh" "$PROJECT_DIR/harness/scripts/"
cp "$TEMPLATES_DIR/scripts/teardown.sh" "$PROJECT_DIR/harness/scripts/"
cp "$TEMPLATES_DIR/scripts/render-prompt.sh" "$PROJECT_DIR/harness/scripts/"
chmod +x "$PROJECT_DIR/harness/scripts/"*.sh

# --- Copy subagent templates ---
cp "$TEMPLATES_DIR/subagents/skill-tester.md" "$PROJECT_DIR/harness/subagents/"
cp "$TEMPLATES_DIR/subagents/evaluator-agent.md" "$PROJECT_DIR/harness/subagents/"

# --- Copy experiment log template ---
cp "$TEMPLATES_DIR/experiment-log/README.md" "$PROJECT_DIR/docs/experiment-log/"

echo ""
echo "=== Harness Scaffolded ==="
echo ""
echo "Created:"
echo "  harness/scripts/setup.sh          — create experiment from scenario"
echo "  harness/scripts/teardown.sh       — clean up fixtures after experiment"
echo "  harness/scripts/render-prompt.sh  — substitute template variables"
echo "  harness/subagents/skill-tester.md"
echo "  harness/subagents/evaluator-agent.md"
echo "  harness/scenarios/                — create your scenarios here"
echo "  docs/experiment-log/README.md     — experiment log index"
echo "  experiments/                      — setup.sh creates experiments here"
echo ""
echo "Next steps:"
echo "  1. Design your first scenario in harness/scenarios/<name>/"
echo "  2. At minimum, create evaluator-briefing.md in the scenario directory"
echo "  3. If your scenario needs fixtures (mock server, sample files),"
echo "     create start-fixture.sh and stop-fixture.sh in the scenario directory"
echo "  4. Run: bash harness/scripts/setup.sh <scenario-name>"
