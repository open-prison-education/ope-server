#!/bin/bash
set -euo pipefail
cd /usr/src/app
if [ -d /usr/src/app/config/ope ]; then
  cp /usr/src/app/config/ope/*.yml /usr/src/app/config/
fi
exec bundle exec script/delayed_job run --no-tail
