#!/bin/sh
# Start Alloy; if GeoLite2 is missing, strip stage.geoip so nginx traffic
# metrics/logs still flow. Geo panels will be empty until the DB is restored.
set -eu

CFG_SRC="/etc/alloy/config.alloy"
CFG_RUN="/tmp/alloy-config.alloy"
GEOIP_DB="/etc/alloy/geoip/GeoLite2-City.mmdb"

if [ -f "$GEOIP_DB" ]; then
  CFG="$CFG_SRC"
else
  echo "WARNING: ${GEOIP_DB} missing — starting without stage.geoip (traffic metrics only; geo panels empty)" >&2
  awk '
    BEGIN { skip=0; depth=0 }
    /^[[:space:]]*stage\.geoip[[:space:]]*\{/ { skip=1; depth=1; next }
    skip {
      n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (c == "{") depth++
        if (c == "}") depth--
      }
      if (depth <= 0) skip=0
      next
    }
    { print }
  ' "$CFG_SRC" > "$CFG_RUN"
  CFG="$CFG_RUN"
fi

exec alloy run "$CFG" \
  --storage.path=/var/lib/alloy/data \
  --server.http.listen-addr=0.0.0.0:12345
