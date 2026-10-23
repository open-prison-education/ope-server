#!/bin/bash
# backup_canvas.sh — Snapshot a running Canvas stack to a timestamped directory
# outside the live database volume.
#
# Usage:
#   backup_canvas.sh              back up this release's Canvas (ope-canvas-postgres)
#   backup_canvas.sh --old-stack  back up an older release's Canvas (ope-postgresql)
#                                 before upgrading. Copy this script onto the old
#                                 server and run it from that ope-server folder.
#
# Captures:
#   postgresql/  custom-format dump of canvas_production
#   files/       uploaded files from volumes/canvas/tmp/files and the facility
#                ID range in volumes/canvas/tmp/db_sequence_range
#   keys/        Canvas encryption keys from volumes/canvas/keys
#   config/      rendered runtime config, config.yml, .secrets.yml, docker-compose.yml
#
# Environment:
#   OPE_BACKUP_ROOT         destination (default: <repo>/backups/canvas)
#   OPE_BACKUP_KEEP_DAYS    delete snapshot folders older than this many days (default: 30)
#   VOLUMES_ROOT            Canvas volume root (default: the .env value, then ./volumes)
#
# The database container must be running. Restore with
# scripts/restore_canvas.sh <backup-dir>.
set -euo pipefail

# Snapshots hold the database, encryption keys, and .secrets.yml.
umask 077

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PG_CONTAINER="ope-canvas-postgres"
case "${1:-}" in
  "") ;;
  --old-stack) PG_CONTAINER="ope-postgresql" ;;
  *)
    echo "usage: backup_canvas.sh [--old-stack]" >&2
    exit 2
    ;;
esac

KEEP_DAYS="${OPE_BACKUP_KEEP_DAYS:-30}"
if ! [[ "$KEEP_DAYS" =~ ^[0-9]+$ ]]; then
  echo "OPE_BACKUP_KEEP_DAYS must be a whole number of days (got '$KEEP_DAYS')." >&2
  exit 2
fi

# Both stacks set a fixed container_name, so docker exec works with Compose v1
# or v2 and does not depend on the current docker-compose.yml.
if ! docker inspect -f '{{.State.Running}}' "$PG_CONTAINER" 2>/dev/null | grep -qx true; then
  echo "The $PG_CONTAINER container is not running. Start it, then run this again." >&2
  exit 1
fi

BACKUP_ROOT="${OPE_BACKUP_ROOT:-$ROOT/backups/canvas}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="$BACKUP_ROOT/$STAMP"

# .env is not a shell script: values such as LMS_ACCOUNT_NAME contain spaces.
# Read VOLUMES_ROOT only.
if [ -z "${VOLUMES_ROOT:-}" ] && [ -f .env ]; then
  VOLUMES_ROOT="$(grep -E '^VOLUMES_ROOT=' .env | head -n 1 | cut -d= -f2- || true)"
fi
VOLUMES_ROOT="${VOLUMES_ROOT:-./volumes}"

echo "Backing up Canvas from $PG_CONTAINER to $DEST"
mkdir -p "$DEST/postgresql" "$DEST/files" "$DEST/config" "$DEST/keys"

docker exec "$PG_CONTAINER" pg_dump -U postgres --format=custom canvas_production \
  > "$DEST/postgresql/canvas_production.dump.partial"
mv "$DEST/postgresql/canvas_production.dump.partial" "$DEST/postgresql/canvas_production.dump"

tmp_entries=()
for entry in files db_sequence_range; do
  if [ -e "$VOLUMES_ROOT/canvas/tmp/$entry" ]; then
    tmp_entries+=("$entry")
  fi
done
if [ "${#tmp_entries[@]}" -gt 0 ]; then
  tar -C "$VOLUMES_ROOT/canvas/tmp" -cf "$DEST/files/files.tar" "${tmp_entries[@]}"
fi
if [ -d "$VOLUMES_ROOT/canvas/keys" ]; then
  tar -C "$VOLUMES_ROOT/canvas" -cf "$DEST/keys/keys.tar" keys
fi
cp -a ope-canvas/runtime-rendered "$DEST/config/runtime-rendered" 2>/dev/null || true
cp -a config.yml "$DEST/config/config.yml" 2>/dev/null || true
cp -a .secrets.yml "$DEST/config/secrets.yml" 2>/dev/null || true
cp -a docker-compose.yml "$DEST/config/docker-compose.yml" 2>/dev/null || true

echo "Wrote $DEST"

# Only remove snapshot folders this script created, so OPE_BACKUP_ROOT can
# point at a shared folder.
find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '????????T??????Z' \
  -mtime +"$KEEP_DAYS" -exec rm -rf {} +
echo "Canvas backup complete."
