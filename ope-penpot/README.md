# OPE Penpot

Open-source design and prototyping platform, integrated into the OPE Server
environment using the official [Penpot Docker installation](https://help.penpot.app/technical-guide/getting-started/docker/).

## Services

| Container | Image | Purpose |
|-----------|-------|---------|
| `penpot-frontend` | `penpotapp/frontend` | Web UI (gateway entry point on port 8080) |
| `penpot-backend` | `penpotapp/backend` | API server |
| `penpot-exporter` | `penpotapp/exporter` | File export worker |
| `penpot-mcp` | `penpotapp/mcp` | Model Context Protocol server |
| `penpot-postgres` | `postgres:15` | Dedicated PostgreSQL database |
| `penpot-valkey` | `valkey/valkey:8.1` | In-memory store (Valkey/Redis compatible) |
| `penpot-mailcatch` | `sj26/mailcatcher` | Dev SMTP server (captures outbound email) |

No custom Dockerfile is needed — all containers use upstream images.

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

## Resources

- [Penpot self-hosting guide](https://help.penpot.app/technical-guide/getting-started/docker/)
- [Penpot configuration reference](https://help.penpot.app/technical-guide/configuration/)
