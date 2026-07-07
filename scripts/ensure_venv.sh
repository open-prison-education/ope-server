#!/bin/bash
# Shared venv bootstrap -- sourced by setup.sh, up.sh, scripts/rebuild.sh
#
# Resolution order:
#   1. Bundled runtime (runtime/python/) — fully offline, no venv needed
#   2. System python3 + venv + pip install (original behavior)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$BASE_DIR/runtime"
VENV_DIR="$BASE_DIR/.venv"
REQ_FILE="$SCRIPT_DIR/requirements.txt"
REQ_HASH_FILE="$VENV_DIR/.requirements_hash"

# ---------------------------------------------------------------------------
# Path 1: Bundled standalone Python (offline / air-gapped deployments)
# ---------------------------------------------------------------------------
BUNDLED_PY="$RUNTIME_DIR/python/bin/python3"
if [ -f "$RUNTIME_DIR/.bundled" ] && [ -x "$BUNDLED_PY" ]; then
    if "$BUNDLED_PY" -c "import yaml" 2>/dev/null; then
        export PATH="$RUNTIME_DIR/python/bin:$PATH"
        return 0 2>/dev/null || exit 0
    else
        echo "WARNING: Bundled runtime found but PyYAML import failed."
        echo "         Falling back to system Python + venv."
    fi
fi

# ---------------------------------------------------------------------------
# Path 2: System Python + venv (online installs)
# ---------------------------------------------------------------------------
PY3="$(which python3 2>/dev/null)"
if [ -z "$PY3" ]; then
    echo "ERROR: python3 is required but not found in PATH."
    echo "       Either install python3 + python3-venv, or use the bundled runtime."
    echo "       See docs/OFFLINE_DISTRIBUTION.md for instructions."
    exit 1
fi

if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment in .venv ..."
    "$PY3" -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

CURRENT_HASH="$(md5sum "$REQ_FILE" 2>/dev/null | cut -d' ' -f1)"
SAVED_HASH=""
if [ -f "$REQ_HASH_FILE" ]; then
    SAVED_HASH="$(cat "$REQ_HASH_FILE")"
fi

if [ "$CURRENT_HASH" != "$SAVED_HASH" ]; then
    echo "Installing Python dependencies ..."
    if pip install -q -r "$REQ_FILE"; then
        echo "$CURRENT_HASH" > "$REQ_HASH_FILE"
    else
        echo "ERROR: pip install failed. Dependencies may be missing."
        exit 1
    fi
fi
