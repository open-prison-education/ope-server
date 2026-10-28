#!/bin/bash
# Nightly backups. Calls backup_canvas.sh for the Canvas snapshot, then dumps
# FOG MySQL.
#
# Crontab, daily at 2:00 AM:
# 0 2 * * * /path/to/ope-server/scripts/export_databases.sh
#
# Optional argument: days to keep (default 30). Passed to backup_canvas.sh as
# OPE_BACKUP_KEEP_DAYS and used for MySQL file cleanup.
set -euo pipefail

if command -v docker-compose >/dev/null 2>&1; then
  compose="docker-compose"
else
  compose="docker compose"
fi
echo "Using Compose: $compose"

current_date=$(date +"%Y%m%d")
DAYS_TO_KEEP=${1:-30}

if ! [[ "$DAYS_TO_KEEP" =~ ^[0-9]+$ ]]; then
  echo "Invalid input for DAYS_TO_KEEP. Defaulting to 30 days." >&2
  DAYS_TO_KEEP=30
fi

cutoff_date=$(date -d "-${DAYS_TO_KEEP} days" +"%Y%m%d")

echo "Writing Canvas backup through scripts/backup_canvas.sh"
OPE_BACKUP_KEEP_DAYS="$DAYS_TO_KEEP" "$(dirname "$0")/backup_canvas.sh"

# FOG MySQL dumps stay inside the FOG data volume.
MYSQL_BACKUP_DIR=/var/lib/mysql/backups
$compose exec -T ope-fog bash -c "mkdir -p ${MYSQL_BACKUP_DIR}"

echo "Dumping MySQL databases..."
$compose exec -T ope-fog bash -c "mysqldump --all-databases > ${MYSQL_BACKUP_DIR}/all_database_${current_date}.sql"

echo "Cleaning up MySQL backup files older than ${DAYS_TO_KEEP} days..."
$compose exec -T ope-fog bash -c "find ${MYSQL_BACKUP_DIR} -type f -name '*.sql' | while read file; do
  file_date=\$(basename \$file | awk -F'[_|.]' '{print \$(NF-1)}')
  if [[ \$file_date < ${cutoff_date} ]]; then
    rm -f \$file
  fi
done"

echo "Database backups completed."
