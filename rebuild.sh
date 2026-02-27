#!/bin/bash
# Rebuild docker-compose.yml and .env from config.yml.

SCRIPT=$(readlink -f "$0")
BASEDIR=$(dirname "$SCRIPT")

# Bootstrap the virtual environment and dependencies
source "$BASEDIR/scripts/ensure_venv.sh"

python3 "$BASEDIR/scripts/rebuild_compose.py"
