#!/bin/sh
# update_penpot_images.sh — Pull upstream Penpot images, re-tag, and push to GHCR.
#
# Usage:
#   ./update_penpot_images.sh 2.16
#
# After it finishes, set PENPOT_VERSION to the same version in .env (or the
# environment), then redeploy with: docker compose up -d

set -eu

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <version>" >&2
    echo "Example: $0 2.16" >&2
    exit 1
fi

NEW_VERSION="$1"
REGISTRY="ghcr.io/open-prison-education"

for img in frontend backend exporter mcp; do
    echo "==> Updating penpot-${img}:${NEW_VERSION}"
    docker pull "penpotapp/${img}:${NEW_VERSION}"
    docker tag "penpotapp/${img}:${NEW_VERSION}" "${REGISTRY}/penpot-${img}:${NEW_VERSION}"
    docker push "${REGISTRY}/penpot-${img}:${NEW_VERSION}"
done

echo
echo "All Penpot images updated to ${NEW_VERSION}."
echo "Set PENPOT_VERSION=${NEW_VERSION} in .env, then run: docker compose up -d"
