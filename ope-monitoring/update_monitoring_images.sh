#!/bin/bash
# update_monitoring_images.sh — Pull upstream monitoring images, re-tag, and
# push to ghcr.io/open-prison-education so they match scripts/export_images.sh.
#
# Usage:
#   ./ope-monitoring/update_monitoring_images.sh [--dry-run] [--no-push]
#
# Environment overrides (optional):
#   PROMETHEUS_VERSION   default: v3.14.0
#   LOKI_VERSION         default: 3.7.6
#   ALLOY_VERSION        default: v1.18.1
#   GRAFANA_VERSION      default: 13.2.0
#   ALERTMANAGER_VERSION default: v0.34.0
#
# After it finishes, ensure compose points at
# ghcr.io/open-prison-education/{prometheus,loki,alloy,grafana,alertmanager}
# (already the case in docker-compose-include.yml), then redeploy with:
#   docker compose up -d
#
# Requires: docker logged in to ghcr.io with push rights, e.g.
#   echo "$GHCR_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin

set -euo pipefail

REGISTRY="ghcr.io/open-prison-education"

PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-v3.14.0}"
LOKI_VERSION="${LOKI_VERSION:-3.7.6}"
ALLOY_VERSION="${ALLOY_VERSION:-v1.18.1}"
GRAFANA_VERSION="${GRAFANA_VERSION:-13.2.0}"
ALERTMANAGER_VERSION="${ALERTMANAGER_VERSION:-v0.34.0}"

DRY_RUN=false
NO_PUSH=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --no-push) NO_PUSH=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--no-push]"
            echo ""
            echo "Pull upstream Prometheus/Grafana images, retag under"
            echo "${REGISTRY}/*, and push to GHCR."
            echo ""
            echo "Options:"
            echo "  --dry-run   Print actions without executing them"
            echo "  --no-push   Pull and retag locally, but do not push"
            echo ""
            echo "Version env vars: PROMETHEUS_VERSION LOKI_VERSION ALLOY_VERSION"
            echo "                  GRAFANA_VERSION ALERTMANAGER_VERSION"
            exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1 ;;
    esac
done

if ! command -v docker &>/dev/null; then
    echo "ERROR: docker is not installed or not in PATH." >&2
    exit 1
fi

# upstream_image  ghcr_name  version
IMAGES=(
    "prom/prometheus|prometheus|${PROMETHEUS_VERSION}"
    "grafana/loki|loki|${LOKI_VERSION}"
    "grafana/alloy|alloy|${ALLOY_VERSION}"
    "grafana/grafana|grafana|${GRAFANA_VERSION}"
    "prom/alertmanager|alertmanager|${ALERTMANAGER_VERSION}"
)

run() {
    if [ "$DRY_RUN" = true ]; then
        echo "    [dry-run] $*"
    else
        "$@"
    fi
}

echo "=== OPE Monitoring: mirror images to GHCR ==="
echo "  Registry: ${REGISTRY}"
echo "  Dry run:  ${DRY_RUN}"
echo "  Push:     $([ "$NO_PUSH" = true ] && echo no || echo yes)"
echo ""

FAILED=0

for entry in "${IMAGES[@]}"; do
    IFS='|' read -r upstream name version <<< "$entry"
    src="${upstream}:${version}"
    dst="${REGISTRY}/${name}:${version}"

    echo "==> ${name}:${version}"
    echo "    pull  ${src}"
    if ! run docker pull "$src"; then
        echo "    [FAILED] pull"
        FAILED=$((FAILED + 1))
        echo ""
        continue
    fi

    echo "    tag   ${dst}"
    if ! run docker tag "$src" "$dst"; then
        echo "    [FAILED] tag"
        FAILED=$((FAILED + 1))
        echo ""
        continue
    fi

    if [ "$NO_PUSH" = true ]; then
        echo "    push  skipped (--no-push)"
    else
        echo "    push  ${dst}"
        if ! run docker push "$dst"; then
            echo "    [FAILED] push"
            FAILED=$((FAILED + 1))
            echo ""
            continue
        fi
    fi
    echo ""
done

echo "=== Done ==="
if [ "$FAILED" -gt 0 ]; then
    echo "  Failed: ${FAILED}"
    exit 1
fi
if [ "$DRY_RUN" = true ]; then
    echo "  (dry-run mode — no changes were made)"
else
    echo "  Images are ready for ./scripts/export_images.sh"
    echo "  Redeploy with: docker compose up -d"
fi
