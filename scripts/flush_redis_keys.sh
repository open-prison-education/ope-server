#!/bin/bash

compose=`which docker-compose`

if [ -z "$compose" ]; then
  compose="docker compose"
fi;
echo "Using Compose: $compose"


# Flush only the Canvas cache DB.
$compose exec ope-canvas-redis sh -c "redis-cli -n 0 flushdb"
# flushall clears ALL dbs.


