#!/usr/bin/env bash
# Set up a test scenario: create a fresh timestamped experiment from a source
# scenario, validate fixture files, run scenario fixtures, render agent prompts.
#
# Usage: setup.sh <source-scenario>
# Example: setup.sh greeting-skill
#
# Source scenarios live in harness/scenarios/.
# Creates a new experiments/YYYYMMDD-HHMM/ directory at the project root.

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: setup.sh <source-scenario>" >&2
    echo "Example: setup.sh greeting-skill" >&2
    exit 1
fi

SOURCE_DIR="$1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$HARNESS_DIR")"

SOURCE_PATH="$HARNESS_DIR/scenarios/$SOURCE_DIR"

# --- Create new timestamped experiment from source scenario ---
if [[ ! -d "$SOURCE_PATH" ]]; then
    echo "Error: Source scenario not found: $SOURCE_PATH" >&2
    echo "Available scenarios:" >&2
    ls "$HARNESS_DIR/scenarios/" 2>/dev/null | while read d; do
        echo "  $d" >&2
    done
    exit 1
fi

EXPERIMENT_NAME="$(date +%Y%m%d-%H%M)"
EXPERIMENT_PATH="$PROJECT_DIR/experiments/$EXPERIMENT_NAME"

if [[ -d "$EXPERIMENT_PATH" ]]; then
    echo "Error: Experiment directory already exists: $EXPERIMENT_PATH" >&2
    echo "Wait a minute and try again, or remove the existing directory." >&2
    exit 1
fi

mkdir -p "$EXPERIMENT_PATH/fixture"
# Copy all files from the scenario (not subdirectories)
find "$SOURCE_PATH" -maxdepth 1 -type f -exec cp {} "$EXPERIMENT_PATH/fixture/" \;
echo "Created experiment: $EXPERIMENT_NAME (from scenario $SOURCE_DIR)"

FIXTURE_DIR="$EXPERIMENT_PATH/fixture"

# --- Validate fixture ---
# Only evaluator-briefing.md is universally required.
# Each scenario type has different fixture files.
REQUIRED_FILES=("evaluator-briefing.md")
MISSING=()
for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$FIXTURE_DIR/$f" ]]; then
        MISSING+=("$f")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Error: Missing required files in $FIXTURE_DIR:" >&2
    for f in "${MISSING[@]}"; do
        echo "  - $f" >&2
    done
    exit 1
fi

echo "Fixture validated: $FIXTURE_DIR"

# --- Copy project-level briefing files ---
# Briefing files in harness/ root apply to all scenarios (e.g., spawning-protocol-briefing.md).
# render-prompt.sh auto-discovers *-briefing.md in the fixture dir.
cp "$HARNESS_DIR/"*-briefing.md "$FIXTURE_DIR/" 2>/dev/null || true

# --- Create output directories ---
mkdir -p "$EXPERIMENT_PATH/output/logs" "$EXPERIMENT_PATH/output/subagent-reports" "$EXPERIMENT_PATH/spawn"
echo "Created output directory: output/"

# --- Run scenario-owned fixture setup ---
if [[ -x "$SOURCE_PATH/start-fixture.sh" ]]; then
    echo "Running scenario fixture setup..."
    bash "$SOURCE_PATH/start-fixture.sh" "$EXPERIMENT_PATH"
    # start-fixture.sh should write variables to $FIXTURE_DIR/.fixture-env
    if [[ -f "$FIXTURE_DIR/.fixture-env" ]]; then
        echo "Fixture environment loaded from .fixture-env"
    fi
elif [[ -f "$SOURCE_PATH/start-fixture.sh" ]]; then
    echo "Running scenario fixture setup..."
    bash "$SOURCE_PATH/start-fixture.sh" "$EXPERIMENT_PATH"
    if [[ -f "$FIXTURE_DIR/.fixture-env" ]]; then
        echo "Fixture environment loaded from .fixture-env"
    fi
fi

# --- Render agent prompts ---
# Loop over all subagent templates in harness/subagents/
for template in "$HARNESS_DIR/subagents/"*.md; do
    if [[ ! -f "$template" ]]; then
        continue
    fi
    agent_name="$(basename "$template" .md)"
    bash "$SCRIPT_DIR/render-prompt.sh" "$agent_name" "$EXPERIMENT_NAME" \
        > "$FIXTURE_DIR/${agent_name}-prompt.md"
    echo "Rendered: fixture/${agent_name}-prompt.md"
done

# --- Summary ---
echo ""
echo "=== Setup Complete ==="
echo "Experiment: $EXPERIMENT_PATH"
echo "Fixture: $FIXTURE_DIR"
echo ""
echo "Rendered prompts:"
ls "$FIXTURE_DIR/"*-prompt.md 2>/dev/null | while read f; do
    echo "  $(basename "$f")"
done
