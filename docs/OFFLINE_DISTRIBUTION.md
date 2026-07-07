# Offline Distribution Guide

This guide explains how to prepare OPE Server for deployment on an **air-gapped
Debian/Ubuntu machine** with no internet access.

**Related:** [Deployment Guide](DEPLOYMENT.md) - Full deployment instructions (assumes internet access)

The approach bundles a standalone CPython interpreter with all dependencies
pre-installed, so the target machine needs **no Python, no pip, and no network**.

---

## Overview

```
┌─────────────────────────────────┐        ┌─────────────────────────────────┐
│  BUILD MACHINE (has internet)   │        │  TARGET MACHINE (air-gapped)    │
│                                 │        │                                 │
│  1. Clone/copy this repo        │  USB   │  1. Extract tarball             │
│  2. Run bundle_runtime.sh       │ ─────► │  2. Run ./setup.sh              │
│  3. Get ope-server-offline.tar  │  or    │     (uses bundled Python,       │
│                                 │  SCP   │      no internet needed)        │
└─────────────────────────────────┘        └─────────────────────────────────┘
```

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

---

## Step 2: Transfer to the Air-Gapped Machine

Copy `ope-server-offline.tar.gz` to the target via:
- USB drive
- SCP through a jump host
- Shared network drive
- Any other method

---

## Step 3: Install on the Target Machine

On the air-gapped Debian/Ubuntu machine:

```bash
# Extract the tarball
tar -xzf ope-server-offline.tar.gz
cd ope-server

# Run setup (uses the bundled Python automatically)
./setup.sh
```

That's it. The `ensure_venv.sh` script detects `runtime/python/` and uses it
directly — no system Python, no venv creation, no pip install, no network
required.

### Verify manually (optional)

```bash
./runtime/python/bin/python3 -c "import yaml; print('OK:', yaml.__version__)"
```

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
