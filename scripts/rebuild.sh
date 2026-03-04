#!/bin/bash
# Rebuild docker-compose.yml and .env from config.yml.

SCRIPT=$(readlink -f "$0")
SCRIPTDIR=$(dirname "$SCRIPT")
BASEDIR=$(dirname "$SCRIPTDIR")

# Bootstrap the virtual environment and dependencies
source "$SCRIPTDIR/ensure_venv.sh"

python3 "$SCRIPTDIR/rebuild_compose.py"
