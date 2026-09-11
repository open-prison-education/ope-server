#!/bin/bash
# export_images.sh — Export Docker images to individual .tar.gz files.
#
# Groups:
#   ope-canvas.tar.gz      — ope-canvas, ope-canvas-rce, ope-canvas-mathman
#   ope-penpot.tar.gz      — penpot-mcp, penpot-exporter, penpot-frontend,
#                            penpot-backend, valkey, mailcatcher, postgres:15
#   ope-monitoring.tar.gz  — prometheus, loki, alloy, grafana, alertmanager
#   All other images       — one .tar.gz each
#
# Usage:
#   ./scripts/export_images.sh [--output-dir /path/to/dir]

set -euo pipefail

REGISTRY="ghcr.io/open-prison-education"
OUTPUT_DIR="./exported_images"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

mkdir -p "$OUTPUT_DIR"

export_images() {
    local tarball="$1"
    shift
    local images=("$@")

    echo "==> Exporting ${tarball}..."
    echo "    Images: ${images[*]}"
    docker save "${images[@]}" | gzip > "${OUTPUT_DIR}/${tarball}"
    echo "    Done. Size: $(du -h "${OUTPUT_DIR}/${tarball}" | cut -f1)"
    echo
}

# Group 1: Canvas
export_images "ope-canvas.tar.gz" \
    "${REGISTRY}/ope-canvas:release" \
    "${REGISTRY}/ope-canvas-rce:release" \
    "${REGISTRY}/ope-canvas-mathman:release"

# Group 2: Penpot
export_images "ope-penpot.tar.gz" \
    "${REGISTRY}/penpot-mcp:2.15" \
    "${REGISTRY}/penpot-exporter:2.15" \
    "${REGISTRY}/penpot-frontend:2.15" \
    "${REGISTRY}/penpot-backend:2.15" \
    "${REGISTRY}/valkey:8.1" \
    "${REGISTRY}/mailcatcher:latest" \
    "${REGISTRY}/postgres:15"

# Group 3: Monitoring
export_images "ope-monitoring.tar.gz" \
    "${REGISTRY}/prometheus:v3.14.0" \
    "${REGISTRY}/loki:3.7.6" \
    "${REGISTRY}/alloy:v1.18.1" \
    "${REGISTRY}/grafana:13.2.0" \
    "${REGISTRY}/alertmanager:v0.34.0"

# Group 4: Individual images
INDIVIDUAL_IMAGES=(
    "ope-dl:release"
    "ope-websites:release"
    "ope-smc:release"
    "ope-gateway:release"
    "ope-redis:release"
    "ope-postgresql:release"
    "ope-dns:release"
    "ope-letsencrypt:release"
)

for entry in "${INDIVIDUAL_IMAGES[@]}"; do
    name="${entry%%:*}"
    export_images "${name}.tar.gz" "${REGISTRY}/${entry}"
done

echo "=== All exports complete ==="
echo "Output directory: ${OUTPUT_DIR}"
ls -lh "${OUTPUT_DIR}"
