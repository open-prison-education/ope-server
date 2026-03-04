#!/bin/bash
# Shared venv bootstrap -- sourced by setup.sh, up.sh, rebuild.sh
# Creates a .venv if needed and installs Python dependencies.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/../.venv"
REQ_FILE="$SCRIPT_DIR/requirements.txt"
REQ_HASH_FILE="$VENV_DIR/.requirements_hash"

PY3="$(which python3 2>/dev/null)"
if [ -z "$PY3" ]; then
    echo "ERROR: python3 is required but not found in PATH."
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
