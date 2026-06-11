#!/bin/bash

SCRIPT=$(readlink -f "$0")
BASEDIR=$(dirname "$SCRIPT")

cd "$BASEDIR"

# Bootstrap the virtual environment and dependencies
source "$BASEDIR/scripts/ensure_venv.sh"

# If config.yml doesn't exist, run the setup wizard first
if [ ! -f "$BASEDIR/config.yml" ]; then
    echo "No config.yml found -- running setup wizard..."
    python3 "$BASEDIR/scripts/setup.py"
    if [ ! -f "$BASEDIR/config.yml" ]; then
        echo "Setup was not completed. Exiting."
        exit 1
    fi
fi

# Check if ope-fog is enabled (from config.yml) and handle SUSE-specific setup
FOG_ENABLED=$(python3 -c "
import yaml, sys
sys.path.insert(0, 'scripts')
try:
    with open('config.yml') as f:
        cfg = yaml.safe_load(f) or {}
    from service_deps import resolve_services
    resolved = resolve_services(cfg.get('services', []))
    print('1' if 'ope-fog' in resolved else '0')
except Exception:
    print('0')
")

if [ "$FOG_ENABLED" = "1" ]; then
    if [ -f /etc/os-release ] && grep -q "SUSE" /etc/os-release 2>/dev/null; then
        systemctl disable rpcbind
        systemctl stop rpcbind

        echo "Ensuring kernel modules are loaded..."
        modprobe nf_conntrack_tftp
        echo "nf_conntrack_tftp" > /etc/modules-load.d/nf_conntrack_tftp.conf
        modprobe nf_nat_tftp
        echo "nf_nat_tftp" > /etc/modules-load.d/nf_nat_tftp.conf
        modprobe nf_conntrack_ftp
        echo "nf_conntrack_ftp" > /etc/modules-load.d/nf_conntrack_ftp.conf
        modprobe nf_conntrack_netbios_ns
        echo "nf_conntrack_netbios_ns" > /etc/modules-load.d/nf_conntrack_netbios_ns.conf
        modprobe nfs
        echo "nfs" > /etc/modules-load.d/nfs.conf
        modprobe nfsd
        echo "nfsd" > /etc/modules-load.d/nfsd.conf
        modprobe ipip
        echo "ipip" > /etc/modules-load.d/ipip.conf
    fi
fi

# Detect docker compose command
compose="$(which docker-compose 2>/dev/null)"
if [ -z "$compose" ]; then
    compose="docker compose"
fi
echo "Using Compose: $compose"

build_flag="${1:-}"

# Rebuild docker-compose.yml and .env from config.yml
python3 "$BASEDIR/scripts/rebuild_compose.py"

if [ "$build_flag" = "b" ]; then
    echo "Building docker containers..."
    $compose build
fi

echo "Bringing up containers..."
$compose up -d --no-build --remove-orphans

# Connect ope-gateway to project's custom bridge networks for proxy routing.
# ope-gateway runs on Docker's default bridge (network_mode: bridge) and cannot
# resolve or reach containers on user-defined networks. Services like Penpot use
# internal networks for DNS resolution; the gateway needs to join those networks
# to proxy traffic to their frontend containers.
project_name=$(basename "$BASEDIR")
for net in $(docker network ls --format '{{.Name}}' --filter driver=bridge 2>/dev/null); do
    case "$net" in
        "${project_name}_"*) docker network connect "$net" ope-gateway 2>/dev/null || true ;;
    esac
done

echo "Done!"
