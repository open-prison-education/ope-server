#!/bin/bash
# export_images.sh — Export Docker images to individual .tar.gz files.
#
# Groups:
#   ope-canvas.tar.gz      — ope-canvas, ope-canvas-rce, ope-canvas-mathman,
#                            ope-canvas-postgres, ope-canvas-redis
#   ope-penpot.tar.gz      — penpot-mcp, penpot-exporter, penpot-frontend,
#                            penpot-backend, valkey, mailcatcher, postgres:15
#   ope-monitoring.tar.gz  — prometheus, loki, alloy, grafana, alertmanager
#   All other images       — one .tar.gz each
#
# The offline release workflow (.github/workflows/offline-release.yml) reads
# these groups with --list and --list-images, so CI and a laptop produce the
# same archives.
#
# Usage:
#   ./scripts/export_images.sh [--output-dir DIR] [--archive NAME] [--pull]
#   ./scripts/export_images.sh --list
#   ./scripts/export_images.sh --list-images NAME
#
#   --output-dir DIR     Where to write archives (default ./exported_images)
#   --archive NAME       Export only this archive, e.g. ope-canvas.tar.gz
#   --pull               docker pull each image before saving it
#   --list               Print every archive name, one per line
#   --list-images NAME   Print the image refs in one archive, one per line

set -euo pipefail

REGISTRY="ghcr.io/open-prison-education"
OUTPUT_DIR="./exported_images"
ONLY_ARCHIVE=""
PULL=0
MODE="export"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --archive) ONLY_ARCHIVE="$2"; shift 2 ;;
        --pull) PULL=1; shift ;;
        --list) MODE="list"; shift ;;
        --list-images) MODE="list-images"; ONLY_ARCHIVE="$2"; shift 2 ;;
        -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

ARCHIVES=()
declare -A ARCHIVE_IMAGES

add_archive() {
    local tarball="$1"
    shift
    ARCHIVES+=("$tarball")
    ARCHIVE_IMAGES["$tarball"]="$*"
}

# Group 1: Canvas
add_archive "ope-canvas.tar.gz" \
    "${REGISTRY}/ope-canvas:release" \
    "${REGISTRY}/ope-canvas-rce:release" \
    "${REGISTRY}/ope-canvas-mathman:release" \
    "${REGISTRY}/ope-canvas-postgres:release" \
    "${REGISTRY}/ope-canvas-redis:release"

# Group 2: Penpot
add_archive "ope-penpot.tar.gz" \
    "${REGISTRY}/penpot-mcp:2.15" \
    "${REGISTRY}/penpot-exporter:2.15" \
    "${REGISTRY}/penpot-frontend:2.15" \
    "${REGISTRY}/penpot-backend:2.15" \
    "${REGISTRY}/valkey:8.1" \
    "${REGISTRY}/mailcatcher:latest" \
    "${REGISTRY}/postgres:15"

# Group 3: Monitoring
add_archive "ope-monitoring.tar.gz" \
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
    "ope-dns:release"
    "ope-letsencrypt:release"
)

for entry in "${INDIVIDUAL_IMAGES[@]}"; do
    name="${entry%%:*}"
    add_archive "${name}.tar.gz" "${REGISTRY}/${entry}"
done

if [ -n "$ONLY_ARCHIVE" ] && [ -z "${ARCHIVE_IMAGES[$ONLY_ARCHIVE]+set}" ]; then
    echo "ERROR: Unknown archive '$ONLY_ARCHIVE'. Run with --list to see archive names." >&2
    exit 1
fi

case "$MODE" in
    list)
        printf '%s\n' "${ARCHIVES[@]}"
        exit 0 ;;
    list-images)
        read -r -a images <<< "${ARCHIVE_IMAGES[$ONLY_ARCHIVE]}"
        printf '%s\n' "${images[@]}"
        exit 0 ;;
esac

export_images() {
    local tarball="$1"
    shift
    local images=("$@")

    echo "==> Exporting ${tarball}..."
    echo "    Images: ${images[*]}"
    if [ "$PULL" -eq 1 ]; then
        for image in "${images[@]}"; do
            docker pull "$image"
        done
    fi
    docker save "${images[@]}" | gzip > "${OUTPUT_DIR}/${tarball}"
    echo "    Done. Size: $(du -h "${OUTPUT_DIR}/${tarball}" | cut -f1)"
    echo
}

mkdir -p "$OUTPUT_DIR"

for tarball in "${ARCHIVES[@]}"; do
    if [ -n "$ONLY_ARCHIVE" ] && [ "$tarball" != "$ONLY_ARCHIVE" ]; then
        continue
    fi
    read -r -a images <<< "${ARCHIVE_IMAGES[$tarball]}"
    export_images "$tarball" "${images[@]}"
done

echo "=== All exports complete ==="
echo "Output directory: ${OUTPUT_DIR}"
ls -lh "${OUTPUT_DIR}"
