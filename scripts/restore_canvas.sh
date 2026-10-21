#!/bin/bash
# Restore a Canvas backup directory created by backup_canvas.sh.
#
# Environment:
#   VOLUMES_ROOT    Canvas volume root (default: the .env value, then ./volumes)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
compose="docker compose"

SRC="${1:-}"
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  echo "usage: restore_canvas.sh <backup-dir>" >&2
  exit 2
fi

# .env is not a shell script: values such as LMS_ACCOUNT_NAME contain spaces.
# Read VOLUMES_ROOT only. Docker Compose loads the rest of .env itself.
if [ -z "${VOLUMES_ROOT:-}" ] && [ -f .env ]; then
  VOLUMES_ROOT="$(grep -E '^VOLUMES_ROOT=' .env | head -n 1 | cut -d= -f2- || true)"
fi

echo "Restoring Canvas from $SRC"
$compose exec -T ope-canvas-postgres pg_restore -U postgres --clean --if-exists --dbname=canvas_production < "$SRC/postgresql/canvas_production.dump" || \
  $compose exec -T ope-canvas-postgres pg_restore -U postgres --dbname=canvas_production < "$SRC/postgresql/canvas_production.dump"

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
