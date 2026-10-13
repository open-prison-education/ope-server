#!/bin/bash
# Restore a Canvas backup directory created by backup_canvas.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
compose="docker compose"

SRC="${1:-}"
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  echo "usage: restore_canvas.sh <backup-dir>" >&2
  exit 2
fi

echo "Restoring Canvas from $SRC"
$compose exec -T ope-postgresql pg_restore -U postgres --clean --if-exists --dbname=canvas_production < "$SRC/postgresql/canvas_production.dump" || \
  $compose exec -T ope-postgresql pg_restore -U postgres --dbname=canvas_production < "$SRC/postgresql/canvas_production.dump"

VOLUMES_ROOT="${VOLUMES_ROOT:-./volumes}"
if [ -f "$SRC/files/files.tar" ]; then
  mkdir -p "$VOLUMES_ROOT/canvas/tmp"
  tar -C "$VOLUMES_ROOT/canvas/tmp" -xf "$SRC/files/files.tar"
fi
if [ -f "$SRC/keys/keys.tar" ]; then
  mkdir -p "$VOLUMES_ROOT/canvas"
  tar -C "$VOLUMES_ROOT/canvas" -xf "$SRC/keys/keys.tar"
fi
echo "Restore complete. Start web/jobs only after verifying migrations."
