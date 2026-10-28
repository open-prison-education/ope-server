#!/bin/bash
set -euo pipefail
cd /usr/src/app
if [ -d /usr/src/app/config/ope ]; then
  cp /usr/src/app/config/ope/*.yml /usr/src/app/config/
fi

mode="${1:-upgrade}"
case "$mode" in
  initial)
    bundle exec rake db:initial_setup
    bundle exec rake ope:production_apply
    ;;
  predeploy)
    bundle exec rake db:migrate:predeploy
    ;;
  upgrade)
    bundle exec rake db:migrate
    bundle exec rake db:load_notifications
    bundle exec rake ope:production_apply
    bundle exec rake brand_configs:generate_and_upload_all
    ;;
  *)
    echo "usage: canvas-migrate.sh [initial|predeploy|upgrade]" >&2
    exit 2
    ;;
esac
