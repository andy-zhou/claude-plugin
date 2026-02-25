#!/usr/bin/env bash
# Clean up after an experiment: stop scenario-owned fixtures, remove temp files.
#
# Usage: teardown.sh [experiment-name]
#
# If experiment-name is not provided, finds the most recent experiment directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$HARNESS_DIR")"

EXPERIMENTS_DIR="$PROJECT_DIR/experiments"

if [[ $# -ge 1 ]]; then
    EXPERIMENT_NAME="$1"
    EXPERIMENT_PATH="$EXPERIMENTS_DIR/$EXPERIMENT_NAME"
else
    # Find most recent experiment
    EXPERIMENT_NAME="$(ls -1 "$EXPERIMENTS_DIR" 2>/dev/null | sort -r | head -1)"
    if [[ -z "$EXPERIMENT_NAME" ]]; then
        echo "No experiments found in $EXPERIMENTS_DIR" >&2
        exit 0
    fi
    EXPERIMENT_PATH="$EXPERIMENTS_DIR/$EXPERIMENT_NAME"
fi

if [[ ! -d "$EXPERIMENT_PATH" ]]; then
    echo "Error: Experiment not found: $EXPERIMENT_PATH" >&2
    exit 1
fi

FIXTURE_DIR="$EXPERIMENT_PATH/fixture"
echo "Tearing down experiment: $EXPERIMENT_NAME"

# --- Run scenario-owned fixture teardown ---
if [[ -f "$FIXTURE_DIR/stop-fixture.sh" ]]; then
    echo "Running scenario fixture teardown..."
    bash "$FIXTURE_DIR/stop-fixture.sh" "$EXPERIMENT_PATH" || true
fi

# --- Clean up .fixture-env and PID files ---
if [[ -f "$FIXTURE_DIR/.fixture-env" ]]; then
    # Read PIDs from .fixture-env and kill them
    while IFS='=' read -r key value; do
        if [[ "$key" == *_PID ]]; then
            pid="${value//[[:space:]]/}"
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                echo "Killed process $pid ($key)"
            fi
        fi
    done < "$FIXTURE_DIR/.fixture-env"
    rm -f "$FIXTURE_DIR/.fixture-env"
    echo "Cleaned up .fixture-env"
fi

# Clean up any PID files in fixture dir
for pidfile in "$FIXTURE_DIR/"*.pid; do
    if [[ -f "$pidfile" ]]; then
        pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            echo "Killed process $pid ($(basename "$pidfile"))"
        fi
        rm -f "$pidfile"
    fi
done

echo "Teardown complete: $EXPERIMENT_NAME"
