#!/bin/bash
# Restore a Canvas backup directory created by backup_canvas.sh.
#
# Environment:
#   VOLUMES_ROOT    Canvas volume root (default: the .env value, then ./volumes)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PG_CONTAINER="ope-canvas-postgres"

SRC="${1:-}"
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  echo "usage: restore_canvas.sh <backup-dir>" >&2
  exit 2
fi
DUMP="$SRC/postgresql/canvas_production.dump"
if [ ! -s "$DUMP" ]; then
  echo "No database dump at $DUMP. Pass the backup folder that contains postgresql/." >&2
  exit 2
fi

# container_name is fixed, so docker exec works with Compose v1 or v2.
if ! docker inspect -f '{{.State.Running}}' "$PG_CONTAINER" 2>/dev/null | grep -qx true; then
  echo "The $PG_CONTAINER container is not running. Start it, then run this again." >&2
  exit 1
fi

# .env is not a shell script: values such as LMS_ACCOUNT_NAME contain spaces.
# Read VOLUMES_ROOT only.
if [ -z "${VOLUMES_ROOT:-}" ] && [ -f .env ]; then
  VOLUMES_ROOT="$(grep -E '^VOLUMES_ROOT=' .env | head -n 1 | cut -d= -f2- || true)"
fi

echo "Restoring Canvas from $SRC"
# Canvas connects as the canvas role. Older releases connected as postgres, so
# their dumps name postgres as owner: restore every object as canvas instead.
# Stop at the first error rather than leaving a mixed database behind.
if ! docker exec -i "$PG_CONTAINER" pg_restore -U postgres \
    --clean --if-exists --no-owner --no-privileges --role=canvas --exit-on-error \
    --dbname=canvas_production < "$DUMP"; then
  echo "Database restore failed. Leave Canvas stopped and follow \"Go back\" in docs/CANVAS_BACKUP_RESTORE.md." >&2
  exit 1
fi

# Volume files belong to the Canvas user inside the container. They must be
# replaced: keeping a key that is already on disk can leave the restored
# database encrypted with a different key. Extract as root when this user
# cannot write the destination.
extract_tar() {
  local archive="$1"
  local dest="$2"
  local target="$3"
  if { [ -e "$target" ] && [ -w "$target" ]; } || { [ ! -e "$target" ] && [ -w "$dest" ]; }; then
    tar -C "$dest" -xf "$archive"
  else
    echo "Replacing files under $target as root."
    sudo tar -C "$dest" -xf "$archive"
  fi
}

VOLUMES_ROOT="${VOLUMES_ROOT:-./volumes}"
if [ -f "$SRC/files/files.tar" ]; then
  mkdir -p "$VOLUMES_ROOT/canvas/tmp"
  extract_tar "$SRC/files/files.tar" "$VOLUMES_ROOT/canvas/tmp" "$VOLUMES_ROOT/canvas/tmp"
fi
if [ -f "$SRC/keys/keys.tar" ]; then
  mkdir -p "$VOLUMES_ROOT/canvas"
  extract_tar "$SRC/keys/keys.tar" "$VOLUMES_ROOT/canvas" "$VOLUMES_ROOT/canvas/keys"
fi
echo "Restore complete."
echo "Backup from this version of Canvas: start Canvas next."
echo "Backup from an older Canvas version: follow \"Upgrade the server from an older Canvas version\" in docs/CANVAS_BACKUP_RESTORE.md before starting Canvas."
