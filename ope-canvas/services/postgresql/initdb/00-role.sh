#!/bin/sh
set -eu
# Create the Canvas login role.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<SQL
CREATE EXTENSION IF NOT EXISTS pg_trgm;
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'canvas') THEN
    CREATE ROLE canvas LOGIN PASSWORD '${IT_PW}';
  END IF;
END
\$\$;
SELECT 'CREATE DATABASE canvas_production OWNER canvas'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'canvas_production')\gexec
REVOKE ALL ON DATABASE canvas_production FROM PUBLIC;
GRANT ALL ON DATABASE canvas_production TO canvas;
SQL
