#!/bin/bash
# OPE Server interactive setup wizard.
# Creates/activates the Python venv, then runs the setup wizard.

SCRIPT=$(readlink -f "$0")
BASEDIR=$(dirname "$SCRIPT")

# Bootstrap the virtual environment and dependencies
source "$BASEDIR/scripts/ensure_venv.sh"

# Run the interactive setup wizard
python3 "$BASEDIR/scripts/setup.py" "$@"
