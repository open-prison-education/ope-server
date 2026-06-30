#!/bin/bash
# bundle_runtime.sh — Build a self-contained Python runtime for offline deployment.
#
# Run this on a machine WITH internet access. It downloads a standalone CPython
# build, extracts it into runtime/python/, and pre-installs project dependencies
# (PyYAML) into that interpreter. The resulting runtime/ directory can then be
# shipped alongside the project for air-gapped use.
#
# Usage:
#   ./scripts/bundle_runtime.sh [--arch x86_64|aarch64] [--python-version 3.12]
#
# The final deliverable is a tarball: ope-server-offline.tar.gz

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNTIME_DIR="$BASE_DIR/runtime"
REQ_FILE="$SCRIPT_DIR/requirements.txt"
TARBALL_OUT="$BASE_DIR/ope-server-offline.tar.gz"

# Defaults
ARCH="${ARCH:-x86_64}"
PY_MAJOR_MINOR="${PY_MAJOR_MINOR:-3.12}"
PY_RELEASE=""
PBS_REPO="https://github.com/astral-sh/python-build-standalone"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            ARCH="$2"; shift 2 ;;
        --python-version)
            PY_MAJOR_MINOR="$2"; shift 2 ;;
        --release)
            PY_RELEASE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--arch x86_64|aarch64] [--python-version 3.12] [--release YYYYMMDD]"
            exit 0 ;;
        *)
            echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Map architecture to python-build-standalone naming
case "$ARCH" in
    x86_64)  PBS_ARCH="x86_64-unknown-linux-gnu" ;;
    aarch64) PBS_ARCH="aarch64-unknown-linux-gnu" ;;
    *)       echo "ERROR: Unsupported arch '$ARCH'. Use x86_64 or aarch64."; exit 1 ;;
esac

# Resolve the release tag (default: latest)
if [ -z "$PY_RELEASE" ]; then
    echo "Fetching latest release tag..."
    PY_RELEASE="$(curl -sfL \
        "https://raw.githubusercontent.com/astral-sh/python-build-standalone/latest-release/latest-release.json" \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['tag'])" 2>/dev/null)"
    if [ -z "$PY_RELEASE" ]; then
        echo "ERROR: Could not determine latest release. Specify --release YYYYMMDD manually."
        echo "       Check available versions at: ${PBS_REPO}/releases"
        exit 1
    fi
    echo "  Using latest release: $PY_RELEASE"
fi

# Resolve the full Python micro version (e.g. 3.12 → 3.12.10) by querying
# the release page for a matching asset name.
echo "Resolving Python ${PY_MAJOR_MINOR}.x version in release ${PY_RELEASE}..."
PY_FULL_VERSION="$(curl -sfL \
    "${PBS_REPO}/releases/expanded_assets/${PY_RELEASE}" \
    | grep -oP "cpython-${PY_MAJOR_MINOR}\.\d+" \
    | sort -t. -k3 -n | tail -1 | sed 's/cpython-//')"

if [ -z "$PY_FULL_VERSION" ]; then
    echo "ERROR: No Python ${PY_MAJOR_MINOR}.x found in release ${PY_RELEASE}."
    echo "       Check available versions at: ${PBS_REPO}/releases/tag/${PY_RELEASE}"
    echo "       check python-build-standalone release page at: ${PBS_REPO}/releases/tag/${PY_RELEASE}"
    exit 1
fi

TARBALL_NAME="cpython-${PY_FULL_VERSION}+${PY_RELEASE}-${PBS_ARCH}-install_only_stripped.tar.gz"
DOWNLOAD_URL="${PBS_REPO}/releases/download/${PY_RELEASE}/${TARBALL_NAME}"

echo "=== OPE Server: Bundle Offline Python Runtime ==="
echo "  Architecture:    $ARCH ($PBS_ARCH)"
echo "  Python version:  $PY_FULL_VERSION (resolved from ${PY_MAJOR_MINOR})"
echo "  Release:         $PY_RELEASE"
echo "  Tarball:         $TARBALL_NAME"
echo "  Download URL:    $DOWNLOAD_URL"
echo ""

# Clean previous runtime and tarball
if [ -d "$RUNTIME_DIR" ]; then
    echo "Removing existing runtime/ directory..."
    rm -rf "$RUNTIME_DIR"
fi
if [ -f "$TARBALL_OUT" ]; then
    echo "Removing existing tarball..."
    rm -f "$TARBALL_OUT"
fi
mkdir -p "$RUNTIME_DIR"

# Download standalone Python
TEMP_TAR="$(mktemp)"
echo "Downloading standalone Python..."
if command -v wget &>/dev/null; then
    wget -q --show-progress -O "$TEMP_TAR" "$DOWNLOAD_URL"
elif command -v curl &>/dev/null; then
    curl -L --progress-bar -o "$TEMP_TAR" "$DOWNLOAD_URL"
else
    echo "ERROR: Neither wget nor curl found."
    exit 1
fi

# Extract — python-build-standalone tarballs extract to a python/ directory
echo "Extracting Python to runtime/..."
tar xf "$TEMP_TAR" -C "$RUNTIME_DIR"
rm -f "$TEMP_TAR"

BUNDLED_PY="$RUNTIME_DIR/python/bin/python3"
if [ ! -x "$BUNDLED_PY" ]; then
    echo "ERROR: Expected $BUNDLED_PY not found after extraction."
    echo "       Check if the tarball name or release tag has changed."
    exit 1
fi

echo "Bundled Python: $("$BUNDLED_PY" --version)"

# Install project dependencies into the bundled Python
echo "Installing dependencies from requirements.txt..."
"$BUNDLED_PY" -m pip install --upgrade pip --quiet
"$BUNDLED_PY" -m pip install -r "$REQ_FILE" --quiet

# Verify
echo "Verifying PyYAML import..."
"$BUNDLED_PY" -c "import yaml; print(f'  PyYAML {yaml.__version__} OK')"

# Create a marker file so ensure_venv.sh knows this is a valid bundled runtime
echo "$PY_FULL_VERSION+$PY_RELEASE ($ARCH)" > "$RUNTIME_DIR/.bundled"

echo ""
echo "=== Runtime bundle complete ==="
echo "  Location: $RUNTIME_DIR/python/"
echo "  Size:     $(du -sh "$RUNTIME_DIR" | cut -f1)"
echo ""

# Create the offline distribution tarball
echo "Creating offline tarball..."
PROJECT_NAME="$(basename "$BASE_DIR")"

tar czf "$TARBALL_OUT" \
    -C "$BASE_DIR/.." \
    --exclude="${PROJECT_NAME}/.git" \
    --exclude="${PROJECT_NAME}/.venv" \
    --exclude="${PROJECT_NAME}/volumes" \
    --exclude="${PROJECT_NAME}/ope-server-offline.tar.gz" \
    --exclude="${PROJECT_NAME}/.secrets.yml" \
    --exclude="${PROJECT_NAME}/config.yml" \
    --exclude="${PROJECT_NAME}/docker-compose.yml" \
    --exclude="${PROJECT_NAME}/.env" \
    --warning=no-file-changed \
    --ignore-failed-read \
    "${PROJECT_NAME}/"

echo "=== Offline tarball created ==="
echo "  File: $TARBALL_OUT"
echo "  Size: $(du -sh "$TARBALL_OUT" | cut -f1)"
echo ""
echo "Transfer this file to the air-gapped machine and extract with:"
echo "  tar xzf ${PROJECT_NAME}-offline.tar.gz"
echo "  cd ${PROJECT_NAME}"
echo "  ./setup.sh"
