# Offline Distribution Guide (Building the Bundle)

This guide is for ** OPE developers** who need to prepare OPE Server
files for deployment on an air-gapped machine.

If you are the **site operator** who already has `ope-server-offline.tar.gz`
and `ope-images.tar.gz`, skip this guide and go straight to the
**[Offline Deployment Guide](OFFLINE_DEPLOYMENT.md)**.

**Related:**
- [Offline Deployment Guide](OFFLINE_DEPLOYMENT.md) -- For site operators: installing from the pre-built files
- [Deployment Guide](DEPLOYMENT.md) -- Full deployment instructions (assumes internet access)

The approach bundles a standalone CPython interpreter with all dependencies
pre-installed, so the target machine needs **no Python, no pip, and no network**.

---

## Overview

```
┌─────────────────────────────────┐        ┌─────────────────────────────────┐
│  BUILD MACHINE (has internet)   │        │  TARGET MACHINE (air-gapped)    │
│                                 │        │                                 │
│  1. Clone repo                  │  USB   │  1. Extract tarball             │
│  2. Run bundle_runtime.sh       │ ─────► │  2. Load Docker images          │
│  3. Export Docker images        │  or    │  3. Run ./setup.sh              │
│  4. Hand off files              │  SCP   │  4. Run ./up.sh                 │
│                                 │        │                                 │
└─────────────────────────────────┘        └─────────────────────────────────┘
```

---

## Prerequisites

| Machine | Requirements |
|---------|-------------|
| **Build machine** (has internet) | `python3`, `tar`, `wget` or `curl`, Docker (to export images) |
| **Target machine** (air-gapped) | Docker Engine 20.10+, Docker Compose v2+ |

The build machine does not need to match the target's OS or architecture.
See the [Deployment Guide](DEPLOYMENT.md#pre-installation) for Docker
installation instructions.

---

## Step 1: Prepare the Bundle (Build Machine)

Run these steps on a machine **with internet access**. This machine does not
need to match the target's OS, but it does need `python3`, `tar`, and either
`wget` or `curl`.

### 1.1 Clone the repository

```bash
git clone https://github.com/open-prison-education/ope-server ope-server
cd ope-server
```

### 1.2 Run the bundle script

For **x86_64** targets (most servers):

```bash
./scripts/bundle_runtime.sh --arch x86_64
```

For **aarch64** (ARM64) targets:

```bash
./scripts/bundle_runtime.sh --arch aarch64
```

This will:
- Download a standalone CPython (~30 MB compressed) from
  [python-build-standalone](https://github.com/indygreg/python-build-standalone)
- Extract it to `runtime/python/`
- Install PyYAML (and any future dependencies) into the bundled interpreter
- Create `ope-server-offline.tar.gz` (~tarball of the entire project)

### 1.3 Verify the bundle (optional)

```bash
./runtime/python/bin/python3 -c "import yaml; print(yaml.__version__)"
```

### 1.4 Export Docker images (if needed)

The tarball contains the scripts and bundled Python runtime but **not** the
Docker images themselves. If the target machine has never pulled images, you
need to export them on the build machine and transfer them separately:

```bash
# On the build machine, pull all images first
./up.sh          # pulls images for all enabled services, then Ctrl-C or run ./down.sh

# Save the images to a file (this can be large, 10-30 GB+)
docker save $(docker images --format '{{.Repository}}:{{.Tag}}' | grep ghcr.io/open-prison-education) \
  | gzip > ope-images.tar.gz
```

> **Tip:** You can also save images selectively. For example, to export only
> Canvas and its dependencies:
> ```bash
> docker save ghcr.io/open-prison-education/ope-canvas:release \
>             ghcr.io/open-prison-education/ope-gateway:release \
>             ghcr.io/open-prison-education/ope-dns:release \
>             ghcr.io/open-prison-education/ope-redis:release \
>             ghcr.io/open-prison-education/ope-postgresql:release \
>             ghcr.io/open-prison-education/ope-canvas-rce:release \
>             ghcr.io/open-prison-education/ope-canvas-mathman:release \
>   | gzip > ope-images.tar.gz
> ```

---

## Step 2: Transfer to the Air-Gapped Machine

Copy the following files to the target via USB drive, SCP through a jump host,
shared network drive, or any other method:

- `ope-server-offline.tar.gz` (scripts + bundled Python runtime)
- `ope-images.tar.gz` (Docker images, if exported in step 1.4)

---

## Step 3: Hand Off to the Site Operator

Give the site operator these two files along with the
**[Offline Deployment Guide](OFFLINE_DEPLOYMENT.md)**, which walks them through
extracting, loading images, running the setup wizard, and starting services.

If you are also the person deploying, follow that guide now.

---

## How It Works

The detection logic in `scripts/ensure_venv.sh`:

1. **Bundled runtime found** (`runtime/.bundled` marker + executable exists):
   - Prepends `runtime/python/bin/` to `PATH`
   - Verifies `import yaml` succeeds
   - Done — no venv, no pip, no network

2. **No bundled runtime** (fallback for dev machines with internet):
   - Uses system `python3`
   - Creates `.venv/` via `python3 -m venv`
   - Runs `pip install -r requirements.txt`

---

## Updating Dependencies

If you add packages to `scripts/requirements.txt`:

1. On the build machine, re-run:
   ```bash
   ./scripts/bundle_runtime.sh
   ```
2. Transfer the new tarball to the target machine.

---

## Supported Platforms

| Target Architecture | Bundle Flag        |
|--------------------|--------------------|
| x86_64 (Intel/AMD) | `--arch x86_64`   |
| aarch64 (ARM64)    | `--arch aarch64`  |

The bundled Python is a fully static/portable build — it works on any
glibc-based Linux (Debian 10+, Ubuntu 20.04+, RHEL 8+, etc.) without
additional system dependencies.
