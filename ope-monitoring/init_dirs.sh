#!/bin/bash
# Create the ope-monitoring data directories with the ownership each image
# expects. Without this, Docker creates the bind-mount targets as root:root and
# four of the five containers -- which run as three different non-root UIDs --
# cannot write to their own data directory and crash on startup.
#
# UIDs are baked into the upstream images:
#   prom/prometheus    nobody (65534)
#   prom/alertmanager  nobody (65534)
#   grafana/loki       10001
#   grafana/grafana    472
#   grafana/alloy      root (0)
#
# Fails loudly rather than letting the stack come up half-broken, since a
# permission error here surfaces later only as an opaque container crash loop.

set -u

DATA_ROOT="${1:-/ope/monitoring}"

# dirname:uid:gid
DIRS="
prometheus:65534:65534
alertmanager:65534:65534
loki:10001:10001
grafana:472:472
alloy:0:0
geoip:0:0
"

# chown needs root; fall back to passwordless sudo when available.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if sudo -n true 2>/dev/null; then
        SUDO="sudo -n"
    fi
fi

echo "Preparing monitoring data directories under ${DATA_ROOT}"

failed=""

for entry in $DIRS; do
    name="${entry%%:*}"
    rest="${entry#*:}"
    uid="${rest%%:*}"
    gid="${rest##*:}"
    path="${DATA_ROOT}/${name}"

    if [ ! -d "$path" ]; then
        if ! $SUDO mkdir -p "$path" 2>/dev/null && ! mkdir -p "$path" 2>/dev/null; then
            echo "  ERROR: cannot create ${path}" >&2
            failed="${failed} ${name}"
            continue
        fi
    fi

    current="$(stat -c '%u:%g' "$path" 2>/dev/null || echo "")"
    if [ "$current" != "${uid}:${gid}" ]; then
        if $SUDO chown "${uid}:${gid}" "$path" 2>/dev/null; then
            echo "  ${path} -> ${uid}:${gid}"
        else
            echo "  ERROR: cannot chown ${path} to ${uid}:${gid} (currently ${current})" >&2
            failed="${failed} ${name}"
            continue
        fi
    fi
    $SUDO chmod 755 "$path" 2>/dev/null || chmod 755 "$path" 2>/dev/null || true
done

if [ -n "$failed" ]; then
    cat >&2 <<EOF

ERROR: could not prepare monitoring data directories:${failed}

These containers run as non-root and will crash-loop on a permission error.
Re-run as root, or prepare the directories manually:

  sudo mkdir -p ${DATA_ROOT}/{prometheus,alertmanager,loki,grafana,alloy,geoip}
  sudo chown 65534:65534 ${DATA_ROOT}/prometheus ${DATA_ROOT}/alertmanager
  sudo chown 10001:10001 ${DATA_ROOT}/loki
  sudo chown 472:472     ${DATA_ROOT}/grafana
  sudo chown 0:0         ${DATA_ROOT}/alloy ${DATA_ROOT}/geoip

EOF
    exit 1
fi

echo "Monitoring data directories ready."

# ---------------------------------------------------------------------------
# GeoIP database installation
# ---------------------------------------------------------------------------
# If GeoLite2-City.mmdb exists at the project root (bundled for air-gap) or
# is passed as the second argument, copy it into the geoip data directory.
# The Alloy container mounts <MONITORING_DATA_ROOT>/geoip → /etc/alloy/geoip.
GEOIP_SRC="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR" 2>/dev/null || echo "$SCRIPT_DIR")"

if [ -z "$GEOIP_SRC" ] && [ -f "${PROJECT_ROOT}/GeoLite2-City.mmdb" ]; then
    GEOIP_SRC="${PROJECT_ROOT}/GeoLite2-City.mmdb"
fi

GEOIP_DEST="${DATA_ROOT}/geoip/GeoLite2-City.mmdb"

if [ -n "$GEOIP_SRC" ] && [ -f "$GEOIP_SRC" ]; then
    if $SUDO cp "$GEOIP_SRC" "$GEOIP_DEST" 2>/dev/null || cp "$GEOIP_SRC" "$GEOIP_DEST" 2>/dev/null; then
        $SUDO chmod 644 "$GEOIP_DEST" 2>/dev/null || chmod 644 "$GEOIP_DEST" 2>/dev/null || true
        echo "GeoIP database installed: ${GEOIP_DEST}"
    else
        echo "WARNING: could not copy GeoIP database to ${GEOIP_DEST}" >&2
    fi
elif [ ! -f "$GEOIP_DEST" ]; then
    echo "NOTE: No GeoLite2-City.mmdb found. GeoIP lookups will be unavailable."
    echo "      Place the database at ${PROJECT_ROOT}/GeoLite2-City.mmdb and re-run,"
    echo "      or download it from https://dev.maxmind.com/geoip/geolite2-free-geolocation-data"
fi
