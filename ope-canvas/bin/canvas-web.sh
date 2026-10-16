#!/bin/bash
set -euo pipefail
cd /usr/src/app
if [ -d /usr/src/app/config/ope ]; then
  cp /usr/src/app/config/ope/*.yml /usr/src/app/config/
fi
rm -f tmp/pids/server.pid
exec bundle exec rails server -b 0.0.0.0 -p 3000
