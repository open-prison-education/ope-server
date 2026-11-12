#!/bin/bash
# upload_release_asset.sh — Upload one file to a GitHub release by release id.
#
# gh release upload addresses a release by tag. A rebuild keeps the published
# release on that tag until the replacement draft has every asset, so an
# upload by tag would attach the file to the old release. This script posts
# to the draft's upload URL, which is tied to the release id.
#
# Usage: upload_release_asset.sh RELEASE_ID FILE
# Env:   GH_TOKEN (read by gh), GH_REPO (owner/name)

set -euo pipefail

usage() {
    echo "Usage: upload_release_asset.sh RELEASE_ID FILE" >&2
}

if [[ $# -ne 2 ]]; then
    usage
    exit 1
fi

release_id="$1"
file="$2"
name="$(basename "$file")"

if [[ -z "$release_id" || -z "$file" ]]; then
    usage
    exit 1
fi
if ! [[ "$release_id" =~ ^[0-9]+$ ]]; then
    echo "ERROR: release id must be numeric, got '${release_id}'." >&2
    exit 1
fi
if [[ ! -f "$file" ]]; then
    echo "ERROR: ${file} does not exist." >&2
    exit 1
fi
if [[ -z "${GH_REPO:-}" ]]; then
    echo "ERROR: GH_REPO is not set." >&2
    exit 1
fi

upload_url="$(gh api "repos/${GH_REPO}/releases/${release_id}" --jq .upload_url)"
# https://uploads.github.com/.../assets{?name,label}
upload_url="${upload_url%\{*}"
if [[ -z "$upload_url" || "$upload_url" != https://uploads.github.com/* ]]; then
    echo "ERROR: release ${release_id} did not return an uploads.github.com URL." >&2
    exit 1
fi
qname="$(jq -nr --arg n "$name" '$n | @uri')"

# A failed attempt can leave the name in place. Remove it before each try
# so the next POST is not rejected as a duplicate.
for attempt in 1 2 3; do
    existing="$(gh api "repos/${GH_REPO}/releases/${release_id}/assets?per_page=100" \
        | jq -r --arg asset "$name" '.[] | select(.name == $asset) | .id')"
    if [[ -n "$existing" ]]; then
        while IFS= read -r asset_id; do
            [[ -z "$asset_id" ]] && continue
            echo "Replacing existing asset ${name} (${asset_id})."
            gh api -X DELETE "repos/${GH_REPO}/releases/assets/${asset_id}" >/dev/null
        done <<<"$existing"
    fi

    if gh api --method POST \
        -H "Accept: application/vnd.github+json" \
        -H "Content-Type: application/octet-stream" \
        --input "$file" \
        "${upload_url}?name=${qname}" >/dev/null; then
        echo "Uploaded ${name} to release ${release_id}."
        exit 0
    fi
    echo "Upload of ${name} failed (attempt ${attempt}/3)." >&2
    if [[ "$attempt" -lt 3 ]]; then
        sleep $((attempt * 5))
    fi
done

echo "ERROR: upload of ${name} to release ${release_id} failed." >&2
exit 1
