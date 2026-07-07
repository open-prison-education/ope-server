#!/bin/bash
# retag_images.sh — Retag local Docker images from operepo/* to ghcr.io/open-prison-education/*
#
# Use this on airgapped servers that still have images cached under the old
# "operepo" Docker Hub namespace. The script finds all local operepo/* images,
# retags them to ghcr.io/open-prison-education/*, and optionally removes the
# old tags.
#
# Usage:
#   ./scripts/retag_images.sh [--remove-old] [--dry-run]
#
# Options:
#   --remove-old   Remove the old operepo/* tags after retagging
#   --dry-run      Show what would be done without executing

set -euo pipefail

OLD_REGISTRY="operepo"
NEW_REGISTRY="ghcr.io/open-prison-education"

REMOVE_OLD=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --remove-old) REMOVE_OLD=true; shift ;;
        --dry-run)    DRY_RUN=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--remove-old] [--dry-run]"
            echo ""
            echo "Retag all local operepo/* Docker images to ghcr.io/open-prison-education/*"
            echo ""
            echo "Options:"
            echo "  --remove-old   Remove old operepo/* tags after retagging"
            echo "  --dry-run      Print actions without executing them"
            exit 0 ;;
        *)
            echo "Unknown option: $1"; exit 1 ;;
    esac
done

if ! command -v docker &>/dev/null; then
    echo "ERROR: docker is not installed or not in PATH."
    exit 1
fi

echo "=== OPE Server: Retag Docker Images ==="
echo "  From: ${OLD_REGISTRY}/*"
echo "  To:   ${NEW_REGISTRY}/*"
echo "  Remove old tags: ${REMOVE_OLD}"
echo "  Dry run: ${DRY_RUN}"
echo ""

# Collect all local images under the old registry namespace
mapfile -t OLD_IMAGES < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep "^${OLD_REGISTRY}/" | sort)

if [ ${#OLD_IMAGES[@]} -eq 0 ]; then
    echo "No images found under '${OLD_REGISTRY}/' — nothing to retag."
    exit 0
fi

echo "Found ${#OLD_IMAGES[@]} image(s) to retag:"
echo ""

RETAGGED=0
FAILED=0

for old_image in "${OLD_IMAGES[@]}"; do
    # Replace the registry prefix: operepo/foo:bar → ghcr.io/open-prison-education/foo:bar
    new_image="${NEW_REGISTRY}/${old_image#${OLD_REGISTRY}/}"

    echo "  ${old_image}"
    echo "    → ${new_image}"

    if [ "$DRY_RUN" = true ]; then
        echo "    [dry-run] skipped"
    else
        if docker tag "$old_image" "$new_image"; then
            RETAGGED=$((RETAGGED + 1))
            if [ "$REMOVE_OLD" = true ]; then
                docker rmi "$old_image" > /dev/null 2>&1 || true
                echo "    [removed old tag]"
            fi
        else
            echo "    [FAILED]"
            FAILED=$((FAILED + 1))
        fi
    fi
    echo ""
done

echo "=== Done ==="
echo "  Retagged: ${RETAGGED}"
if [ "$FAILED" -gt 0 ]; then
    echo "  Failed:   ${FAILED}"
fi
if [ "$DRY_RUN" = true ]; then
    echo "  (dry-run mode — no changes were made)"
fi
