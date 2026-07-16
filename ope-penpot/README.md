# OPE Penpot

Open-source design and prototyping platform, integrated into the OPE Server
environment using the official [Penpot Docker installation](https://help.penpot.app/technical-guide/getting-started/docker/).

## Services

| Container | Image | Purpose |
|-----------|-------|---------|
| `penpot-frontend` | `ghcr.io/open-prison-education/penpot-frontend` | Web UI (gateway entry point on port 8080) |
| `penpot-backend` | `ghcr.io/open-prison-education/penpot-backend` | API server |
| `penpot-exporter` | `ghcr.io/open-prison-education/penpot-exporter` | File export worker |
| `penpot-mcp` | `ghcr.io/open-prison-education/penpot-mcp` | Model Context Protocol server |
| `penpot-postgres` | `ghcr.io/open-prison-education/postgres:15` | Dedicated PostgreSQL database |
| `penpot-valkey` | `ghcr.io/open-prison-education/valkey:8.1` | In-memory store (Valkey/Redis compatible) |
| `penpot-mailcatch` | `ghcr.io/open-prison-education/mailcatcher` | Dev SMTP server (captures outbound email) |

No custom Dockerfile is needed — Penpot containers are mirrored from upstream
`penpotapp/*` images into our GHCR registry (see [Updating Penpot](#updating-penpot)).

## Access

Once enabled and running, Penpot is available at `https://penpot.<DOMAIN>`
(e.g. `https://penpot.ed` with the default domain).

## Configuration

Key environment variables are set in `docker-compose-include.yml`.
See the [Penpot configuration docs](https://help.penpot.app/technical-guide/configuration/)
for the full list of flags and options.

The `PENPOT_SECRET_KEY` is auto-generated and stored in `.secrets.yml` on
first run. To pin a specific Penpot version, set the `PENPOT_VERSION`
environment variable (defaults to `2.15`).

## Updating Penpot

When Penpot releases a new version (e.g. `2.16`), mirror the upstream images
into our registry, then bump `PENPOT_VERSION`.

### 1. Pull new images from Penpot's registry

```bash
NEW_VERSION=2.16

docker pull penpotapp/frontend:${NEW_VERSION}
docker pull penpotapp/backend:${NEW_VERSION}
docker pull penpotapp/exporter:${NEW_VERSION}
docker pull penpotapp/mcp:${NEW_VERSION}
```

### 2. Re-tag for our registry

```bash
REGISTRY="ghcr.io/open-prison-education"
NEW_VERSION=2.16

docker tag penpotapp/frontend:${NEW_VERSION} ${REGISTRY}/penpot-frontend:${NEW_VERSION}
docker tag penpotapp/backend:${NEW_VERSION} ${REGISTRY}/penpot-backend:${NEW_VERSION}
docker tag penpotapp/exporter:${NEW_VERSION} ${REGISTRY}/penpot-exporter:${NEW_VERSION}
docker tag penpotapp/mcp:${NEW_VERSION} ${REGISTRY}/penpot-mcp:${NEW_VERSION}
```

### 3. Push to our registry

```bash
docker push ${REGISTRY}/penpot-frontend:${NEW_VERSION}
docker push ${REGISTRY}/penpot-backend:${NEW_VERSION}
docker push ${REGISTRY}/penpot-exporter:${NEW_VERSION}
docker push ${REGISTRY}/penpot-mcp:${NEW_VERSION}
```

### 4. Update the environment variable

In your `.env` file (or wherever `PENPOT_VERSION` is set):

```
PENPOT_VERSION=2.16
```

No changes to `docker-compose-include.yml` are needed because it uses
`${PENPOT_VERSION:-2.15}`.

### 5. Redeploy

```bash
docker compose up -d
```

### Important notes

- Do **not** change the compose image names back to `penpotapp/` — compose
  files should always reference `ghcr.io/open-prison-education/penpot-*`. The
  upstream pull is only a temporary step to get the image; then re-tag and push.
- The `penpotapp/` prefix becomes `penpot-` in our registry (slash replaced
  with a dash) because ghcr.io does not support nested namespaces beyond the
  org level.
- Postgres and Valkey rarely need updating for Penpot unless the release notes
  explicitly require it. Check Penpot's changelog before upgrading those.
- Keep the old version mirrored — do not delete old tags from the registry in
  case you need to roll back.

### Quick update script

For convenience, use the helper script in this directory:

```bash
./update_penpot_images.sh 2.16
```

This pulls, re-tags, and pushes all four Penpot images. After it finishes, set
`PENPOT_VERSION` in `.env` and run `docker compose up -d`.

## Resources

- [Penpot self-hosting guide](https://help.penpot.app/technical-guide/getting-started/docker/)
- [Penpot configuration reference](https://help.penpot.app/technical-guide/configuration/)
