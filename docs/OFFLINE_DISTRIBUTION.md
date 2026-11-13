# Offline Distribution Guide (Building the Bundle)

This guide is for **OPE developers** who need to prepare OPE Server
files for deployment on an air-gapped machine.

If you are the **site operator** who already has `ope-server-offline.tar.gz`
and the image archives, skip this guide and go straight to the
**[Offline Deployment Guide](OFFLINE_DEPLOYMENT.md)**.

**Related:**
- [Offline Deployment Guide](OFFLINE_DEPLOYMENT.md) -- For site operators: installing from the pre-built files
- [Deployment Guide](DEPLOYMENT.md) -- Full deployment instructions (assumes internet access)

The approach bundles a standalone CPython interpreter with all dependencies
pre-installed, so the target machine needs **no Python, no pip, and no network**.

---

## Published Releases (GitHub Actions)

The usual way to produce the bundle is the **Offline release** workflow
(`.github/workflows/offline-release.yml`). It publishes a GitHub Release
containing every file a site needs.

**To publish a new release:** open the repository's **Actions** tab, pick
**Offline release**, click **Run workflow**, leave the branch on `main`, and
leave the tag input empty. The workflow tags the latest commit on `main` as
`yy.mm.dd.build` (UTC date, no zero padding, no `v` prefix) and publishes
that release. The first run on 6 Nov 2026 creates `26.11.6.0`; a second run
that day creates `26.11.6.1`. A run started from any other branch fails when
the tag input is empty.

**To rebuild an existing release:** run **Offline release** again, leave the
branch on `main`, and enter that tag in the tag input, for example
`26.11.6.0`. The workflow checks the tag out and rebuilds it. It does not
create a new build number. The published release stays available until the
new draft has every asset, then it is replaced. If the rebuild fails before
that, the published release is left as it was.

`git push origin 26.11.6.0` does not rebuild a release. When the remote
already has that tag, Git prints "Everything up-to-date" and no workflow
runs. The tag push trigger runs only when that tag ref is updated, such as
the first push of a new tag. Merges to `main` never publish.

The workflow pulls images from GHCR (`:release` and the pinned Penpot and
monitoring tags) rather than building them, so a re-run picks up whatever
those tags point at that day. Each release contains:

- `ope-server-offline.tar.gz` from `bundle_runtime.sh --arch x86_64`
- One archive per group in `scripts/export_images.sh` (see
  [step 1.4](#14-export-docker-images-if-needed))
- `SHA256SUMS`, and `manifest.json` listing the image refs, digests, file
  names, and sizes in each archive

The release stays a draft until every file that will be attached has
uploaded. Uploads go to that draft by release id, so a rebuild cannot attach
files to the release that is still published. On a rebuild, the published
release is deleted only after the new draft has every asset, and then the
new one is published. If a job fails before that, the draft is deleted, the
published release stays, and the git tag is kept, so a failed build number
is not reused.

GitHub rejects release files of 2 GiB or more. An image archive at or over
that size is left out of the release, and the rest of the bundle is still
published. `manifest.json` records that file with `"omitted": true`, the
size the workflow measured, and a `location` of
`https://dl.corrections.sbctc.edu/releases/<version>/app_images/<file>`.
`SHA256SUMS` lists only the files attached to the release. Build the omitted
archive by hand and upload it to that location:

```bash
./scripts/export_images.sh --archive ope-canvas.tar.gz --pull
```

The workflow does not upload to that host. While the archive stays over the
cap, later runs keep publishing the release without it. `size` and the image
digests in the manifest describe the archive the workflow built and did not
upload; a later hand build can differ if `:release` has moved. If
`ope-server-offline.tar.gz` itself is at or over 2 GiB, that job fails, the
draft is deleted, and a published release is left in place.

If a pull is denied because a package is private to another repository, add
a `GHCR_READ_TOKEN` repository secret with the `read:packages` scope.

The rest of this guide is the manual path, for custom or aarch64 builds.

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
>             ghcr.io/open-prison-education/ope-canvas-redis:release \
>             ghcr.io/open-prison-education/ope-canvas-postgres:release \
>             ghcr.io/open-prison-education/ope-canvas-rce:release \
>             ghcr.io/open-prison-education/ope-canvas-mathman:release \
>   | gzip > ope-images.tar.gz
> ```

**One archive per service group** (the same files the release workflow
publishes):

```bash
./scripts/export_images.sh --pull [--output-dir DIR]
```

This writes:

- `ope-canvas.tar.gz` with all five Canvas images. RCE, Mathman, Postgres, and
  Redis ship as Canvas dependencies rather than separate services:
  `ope-canvas`, `ope-canvas-rce`, `ope-canvas-mathman`,
  `ope-canvas-postgres`, `ope-canvas-redis`
- `ope-penpot.tar.gz` and `ope-monitoring.tar.gz` with their groups
- One `.tar.gz` for each remaining image (`ope-smc.tar.gz`,
  `ope-gateway.tar.gz`, and so on)

Run `./scripts/export_images.sh --list` to see every archive name, and
`--archive NAME` to export just one. Without `--pull`, the images must
already be on the build machine.

---

## Step 2: Transfer to the Air-Gapped Machine

Copy the following files to the target via USB drive, SCP through a jump host,
shared network drive, or any other method:

- `ope-server-offline.tar.gz` (scripts + bundled Python runtime)
- The image archives from step 1.4 (`ope-images.tar.gz`, or the per-group
  `.tar.gz` files)

---

## Step 3: Hand Off to the Site Operator

Give the site operator these files along with the
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
