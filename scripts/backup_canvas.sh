#!/bin/bash
# backup_canvas.sh — Snapshot a running Canvas stack to a timestamped directory
# outside the live database volume.
#
# Captures:
#   postgresql/  custom-format dump of canvas_production
#   files/       uploaded files from volumes/canvas/tmp/files
#   keys/        Canvas encryption keys from volumes/canvas/keys
#   config/      rendered runtime config, config.yml, .secrets.yml, docker-compose.yml
#
# Environment:
#   OPE_BACKUP_ROOT         destination (default: <repo>/backups/canvas)
#   OPE_BACKUP_KEEP_DAYS    delete backups older than this many days (default: 30)
#   VOLUMES_ROOT            Canvas volume root (default: the .env value, then ./volumes)
#
# Requires the ope-canvas-postgres container to be running. Restore with
# scripts/restore_canvas.sh <backup-dir>.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

compose="docker compose"
BACKUP_ROOT="${OPE_BACKUP_ROOT:-$ROOT/backups/canvas}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="$BACKUP_ROOT/$STAMP"
mkdir -p "$DEST"

# .env is not a shell script: values such as LMS_ACCOUNT_NAME contain spaces.
# Read VOLUMES_ROOT only. Docker Compose loads the rest of .env itself.
if [ -z "${VOLUMES_ROOT:-}" ] && [ -f .env ]; then
  VOLUMES_ROOT="$(grep -E '^VOLUMES_ROOT=' .env | head -n 1 | cut -d= -f2- || true)"
fi

echo "Backing up Canvas to $DEST"
mkdir -p "$DEST/postgresql" "$DEST/files" "$DEST/config" "$DEST/keys"

$compose exec -T ope-canvas-postgres pg_dump -U postgres --format=custom --file=/tmp/canvas_production.dump canvas_production
$compose cp ope-canvas-postgres:/tmp/canvas_production.dump "$DEST/postgresql/canvas_production.dump"
$compose exec -T ope-canvas-postgres rm -f /tmp/canvas_production.dump

VOLUMES_ROOT="${VOLUMES_ROOT:-./volumes}"
if [ -d "$VOLUMES_ROOT/canvas/tmp/files" ]; then
  tar -C "$VOLUMES_ROOT/canvas/tmp" -cf "$DEST/files/files.tar" files
fi
if [ -d "$VOLUMES_ROOT/canvas/keys" ]; then
  tar -C "$VOLUMES_ROOT/canvas" -cf "$DEST/keys/keys.tar" keys
fi
cp -a ope-canvas/runtime-rendered "$DEST/config/runtime-rendered" 2>/dev/null || true
cp -a config.yml "$DEST/config/config.yml" 2>/dev/null || true
cp -a .secrets.yml "$DEST/config/secrets.yml" 2>/dev/null || true
cp -a docker-compose.yml "$DEST/config/docker-compose.yml" 2>/dev/null || true

echo "Wrote $DEST"

find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -mtime +"${OPE_BACKUP_KEEP_DAYS:-30}" -exec rm -rf {} +
echo "Canvas backup complete."
