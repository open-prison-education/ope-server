# Open Prison Education (OPE) Server

OPE Server is a collection of Docker containers that work together to provide a complete educational environment. It is specifically designed to operate in restricted network environments such as correctional facilities, where internet access may be limited or unavailable.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         OPE Gateway (nginx)                         │
│                    Reverse proxy & SSL termination                  │
└─────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────┐         ┌─────────────────┐         ┌───────────────┐
│  Canvas LMS   │         │      SMC        │         │   Other Apps  │
│  (ope-canvas) │         │   (ope-smc)     │         │               │
└───────────────┘         └─────────────────┘         └───────────────┘
        │                           │                           │
        └───────────────────────────┼───────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────┐         ┌─────────────────┐         ┌───────────────┐
│  PostgreSQL   │         │     Redis       │         │      DNS      │
│(ope-postgresql)│        │   (ope-redis)   │         │   (ope-dns)   │
└───────────────┘         └─────────────────┘         └───────────────┘
```

## Services

| Service | Description |
|---------|-------------|
| **ope-canvas** | Canvas LMS - Learning Management System by Instructure |
| **ope-canvas-rce** | Rich Content Editor service for Canvas |
| **ope-canvas-mathman** | Math equation rendering service for Canvas |
| **ope-smc** | Student Management Console - User management and content sync |
| **ope-gateway** | Nginx reverse proxy with SSL termination |
| **ope-postgresql** | PostgreSQL database server |
| **ope-redis** | Redis cache server |
| **ope-dns** | DNS server for local domain resolution |
| **ope-ntp** | NTP time synchronization server |
| **ope-fog** | FOG Project imaging server for system deployment |
| **ope-kalite** | Khan Academy Lite offline content |
| **ope-gcf** | GCFLearnFree.org offline content |
| **ope-codecombat** | CodeCombat coding education platform |
| **ope-freecodecamp** | freeCodeCamp offline content |
| **ope-jsbin** | JS Bin code playground |
| **ope-rachel** | RACHEL offline educational content |
| **ope-git** | Git server for code repositories |
| **ope-websites** | OSN approved websites |

## Prerequisites

- Linux server (Ubuntu 20.04+ recommended)
- Docker Engine 20.10+
- Docker Compose v2+
- Python 3.6+
- Minimum 8GB RAM
- 500GB+ storage (varies based on content)

## Quick Start

1. **Clone the repository:**

```bash
git clone https://github.com/open-prison-education/ope-server
cd ope-server
```

2. **Run the interactive setup wizard:**

```bash
./setup.sh
```

The wizard walks you through network settings, passwords, and service
selection. It writes `config.yml` (and `.secrets.yml` for auto-generated
secrets). Alternatively, copy the example config and edit it by hand:

```bash
cp config.yml.example config.yml
# Edit config.yml with your settings
```

Core services (`ope-gateway`, `ope-dns`) and any dependencies (e.g.
`ope-redis`, `ope-postgresql` for Canvas) are resolved automatically --
you only need to list the services you actually want.

3. **Start enabled services:**

```bash
./up.sh
```

If `config.yml` does not exist yet, `up.sh` will launch the setup wizard
automatically before starting containers.

4. **Stop enabled services and remove containers:**

```bash
./down.sh
```

## Directory Structure

```
ope-server/
├── config.yml.example       # Example configuration (copy to config.yml)
├── config.yml               # Your active configuration (git-ignored)
├── .secrets.yml             # Auto-generated secrets (git-ignored)
├── .env.template            # Environment variable template
├── setup.sh                 # Interactive setup wizard
├── up.sh                    # Rebuild compose & start services
├── down.sh                  # Stop enabled services and remove containers
├── scripts/
│   ├── setup.py             # Setup wizard logic
│   ├── rebuild_compose.py   # Generates docker-compose.yml & .env
│   ├── rebuild.sh           # Script to generates docker-compose.yml & .env only, a wrapper for rebuild_compose.py
│   ├── service_deps.py      # Service dependency map
│   ├── ensure_venv.sh       # Python venv bootstrap (sourced by shell scripts)
│   ├── requirements.txt     # Python dependencies
│   ├── push_images.py       # Push images to registry
│   ├── export_databases.sh  # Backup PostgreSQL and MySQL databases
│   ├── flush_redis_keys.sh  # Clear Redis cache
│   └── recompile_canvas_assets.sh  # Recompile Canvas assets
├── docs/                    # Documentation
└── ope-*/                   # Individual service directories
```

## Management Commands

| Command | Description |
|---------|-------------|
| `./setup.sh` | Run the interactive setup wizard (creates `config.yml`) |
| `./up.sh` | Rebuild compose files and start all configured services (pulls pre-built images from the registry) |
| `./up.sh b` | Build images locally from source instead of pulling from the registry, then start services |
| `./down.sh` | Stop all containers |
| `./scripts/rebuild.sh` | Regenerate `docker-compose.yml` and `.env` without starting containers |
| `./scripts/export_databases.sh` | Backup PostgreSQL and MySQL databases |
| `./scripts/flush_redis_keys.sh` | Clear Redis cache |

## Configuration

The system is configured through:

1. **`config.yml`** - Main configuration file listing enabled services and settings. Generated by `./setup.sh` or copied from `config.yml.example`.
2. **`.secrets.yml`** - Auto-generated secrets (Canvas encryption keys, etc.). Not committed to version control.
3. **`.env` / `.env.template`** - Environment variables consumed by Docker Compose. The `.env` file is regenerated automatically by `rebuild_compose.py` from the template and `config.yml` values -- do not edit it by hand.
4. **`docker-compose-include.yml`** - Per-service Docker Compose fragments assembled into the final `docker-compose.yml` at build time.

To reconfigure the server, either edit `config.yml` directly or re-run `./setup.sh`.

## Adding a New Service

To add a new service (e.g. `ope-myapp`):

1. Create the service directory with a `docker-compose-include.yml` (and optionally a `volumes-include.yml`):

```
ope-myapp/
├── Dockerfile
├── docker-compose-include.yml
└── README.md
```

2. Register the service in `scripts/service_deps.py`:
   - Add an entry to **`SERVICE_DEPS`** mapping the service name to its dependency list (e.g. `"ope-myapp": ["ope-gateway", "ope-dns"]`). Use an empty list `[]` if it has no dependencies beyond the core services.
   - Add it to the appropriate group in **`SERVICE_CATALOG`** so it appears in the `./setup.sh` interactive wizard. If you skip this step, users can still enable it by hand-editing `config.yml`, but the wizard won't present it as an option.

3. Add it as a commented-out entry in `config.yml.example` so users can discover it.

4. Enable the service in `config.yml` and run `./up.sh b` to build all enabled servies and stert them. Or run `docker compose build ope-myapp` to build only your app, then `up.sh` start services.

## Deployment

For a complete deployment walkthrough -- system requirements, Docker installation, configuration, SSL, DNS, backups, and public deployment hardening (e.g. preventing search engine crawling) -- see the **[Deployment Guide](docs/DEPLOYMENT.md)**.

Once services are running, the **[Accessing Services Guide](docs/ACCESSING_SERVICES.md)** covers how to reach Canvas, SMC, and other applications -- including DNS setup for air-gapped environments and remote access via public IP.

## Development

To work on individual services:

1. Navigate to the service directory (e.g., `cd ope-smc`)
2. Make changes to Dockerfile or configuration
3. Rebuild with `./scripts/rebuild.sh`
4. run `docker compose build ope-smc`
5. run `up.sh`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is open source. See individual service directories for specific licensing information.

## Support

- GitHub Issues: [https://github.com/open-prison-education/ope-server/issues](https://github.com/open-prison-education/ope-server/issues)
