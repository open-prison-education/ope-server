#!/bin/bash
# push_images.sh — Push locally built OPE images to GHCR.
#
# Compose tags images this repository builds as
# ghcr.io/open-prison-education/<name>:release (a few use :latest).
# This script reads those names from each service's docker-compose-include.yml
# and pushes the ones that exist locally. It skips images that have not been
# built on this machine.
#
# Mirrored images (monitoring, Penpot, and their databases) are pushed by
# ope-monitoring/update_monitoring_images.sh and ope-penpot/update_penpot_images.sh.
#
# Usage:
#   echo "$GHCR_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin
#   ./scripts/rebuild.sh && docker compose build
#   ./scripts/push_images.sh [--dry-run]
#
# `docker compose build` and `./up.sh b` only build services enabled in
# config.yml. `./up.sh b` also starts the stack and removes orphaned containers.
#
# The GHCR token needs the write:packages scope.
#
# Options:
#   --dry-run   Show what would be pushed without contacting the registry

set -euo pipefail

REGISTRY="ghcr.io/open-prison-education"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--dry-run]"
            echo ""
            echo "Push locally built ${REGISTRY} images."
            echo "Images that are not present locally are skipped."
            echo ""
            echo "Log in first (PAT with write:packages):"
            echo '  echo "$GHCR_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin'
            echo ""
            echo "Options:"
            echo "  --dry-run   Print actions without pushing"
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

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: docker is not running, or this user cannot talk to the daemon." >&2
    exit 1
fi

# Services that set `build:` contribute their ghcr.io image. The key may be a
# path on the same line (`build: ./ope-foo`) or a mapping (`build:` with
# `context:` on the following lines). Other services in the same file (jobs
# that reuse an image, upstream mirrors) are ignored.
collect_built_images() {
    local file line svc_has_build svc_image image files
    shopt -s nullglob
    files=("$ROOT"/ope-*/docker-compose-include.yml)
    shopt -u nullglob
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "ERROR: no docker-compose-include.yml files found under $ROOT" >&2
        exit 1
    fi

    for file in "${files[@]}"; do
        svc_has_build=false
        svc_image=""
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^[[:space:]]{4}[^[:space:]#][^:]*:[[:space:]]*$ ]]; then
                if [[ "$svc_has_build" == true && -n "$svc_image" ]]; then
                    printf '%s\n' "$svc_image"
                fi
                svc_has_build=false
                svc_image=""
            elif [[ "$line" =~ ^[[:space:]]+build:[[:space:]]*(#.*)?$ ]] || [[ "$line" =~ ^[[:space:]]+build:[[:space:]]+[^[:space:]#] ]]; then
                svc_has_build=true
            elif [[ "$line" =~ ^[[:space:]]+image:[[:space:]]*(.*)$ ]]; then
                image="${BASH_REMATCH[1]}"
                image="${image%%#*}"
                image="${image//\"/}"
                image="${image//\'/}"
                image="${image#"${image%%[![:space:]]*}"}"
                image="${image%"${image##*[![:space:]]}"}"
                if [[ "$image" == ${REGISTRY}/* && "$image" != *\$* ]]; then
                    if [[ "${image##*/}" != *:* ]]; then
                        image="${image}:latest"
                    fi
                    svc_image="$image"
                fi
            fi
        done < "$file"
        if [[ "$svc_has_build" == true && -n "$svc_image" ]]; then
            printf '%s\n' "$svc_image"
        fi
    done
}

mapfile -t IMAGES < <(collect_built_images | sort -u)

if [[ ${#IMAGES[@]} -eq 0 ]]; then
    echo "ERROR: no built ${REGISTRY} images found in docker-compose-include.yml files." >&2
    exit 1
fi

echo "=== OPE Server: Push built images ==="
echo "  Registry: ${REGISTRY}"
echo "  Dry run:  ${DRY_RUN}"
echo ""

PUSHED=0
SKIPPED=0
FAILED=0

for image in "${IMAGES[@]}"; do
    echo "==> ${image}"
    if ! docker image inspect "$image" >/dev/null 2>&1; then
        echo "    skip  not present locally (enable it in config.yml, then ./scripts/rebuild.sh && docker compose build)"
        SKIPPED=$((SKIPPED + 1))
        echo ""
        continue
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "    [dry-run] docker push ${image}"
        PUSHED=$((PUSHED + 1))
    elif docker push "$image"; then
        PUSHED=$((PUSHED + 1))
    else
        echo "    [FAILED] push"
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

echo "=== Done ==="
if [[ "$DRY_RUN" == true ]]; then
    echo "  Would push: ${PUSHED}"
else
    echo "  Pushed:     ${PUSHED}"
fi
echo "  Skipped:    ${SKIPPED}"
if [[ "$FAILED" -gt 0 ]]; then
    echo "  Failed:     ${FAILED}"
    echo ""
    echo "If the errors say unauthorized or denied, log in with a token that has write:packages:" >&2
    echo '  echo "$GHCR_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin' >&2
    exit 1
fi
if [[ "$DRY_RUN" == true ]]; then
    echo "  (dry-run mode — no images were pushed)"
fi
