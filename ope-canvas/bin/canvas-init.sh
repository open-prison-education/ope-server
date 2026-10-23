#!/bin/bash
# Create the Canvas schema when canvas_production has no public tables.
# An existing schema is left unchanged. predeploy and upgrade stay on
# canvas-migrate.sh, run by the operator.

set -euo pipefail
cd /usr/src/app
if [ -d /usr/src/app/config/ope ]; then
  cp /usr/src/app/config/ope/*.yml /usr/src/app/config/
fi

psql_canvas() {
  PGPASSWORD="$IT_PW" psql -h postgresql -U canvas "$@"
}

ready=0
for _ in $(seq 1 60); do
  if psql_canvas -d postgres -tAc "SELECT 1" | grep -q 1; then
    ready=1
    break
  fi
  sleep 2
done
if [ "$ready" != "1" ]; then
  echo "PostgreSQL did not accept Canvas connections." >&2
  exit 1
fi

db_state="$(psql_canvas -d postgres -tAc \
  "SELECT 1 FROM pg_database WHERE datname = 'canvas_production'" | tr -d '[:space:]')"
if [ "$db_state" = "1" ]; then
  tables="$(psql_canvas -d canvas_production -tAc \
    "SELECT COUNT(*) FROM pg_catalog.pg_tables WHERE schemaname = 'public'" | tr -d '[:space:]')"
  case "$tables" in
    ''|*[!0-9]*)
      echo "Could not read Canvas table count ($tables)." >&2
      exit 1
      ;;
  esac
  if [ "$tables" != "0" ]; then
    echo "Canvas database already has tables. Skipping initial setup."
    exit 0
  fi
fi

echo "Canvas database is empty. Creating the schema (this can take a while)..."
exec /usr/local/bin/canvas-migrate.sh initial
