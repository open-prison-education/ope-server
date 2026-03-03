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

## Prerequisites

- Linux server (Ubuntu 20.04+ recommended)
- Docker Engine 20.10+
- Docker Compose v2+
- Python 3.6+
- Minimum 16GB RAM
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

3. **Start the services:**

```bash
./up.sh
```

If `config.yml` does not exist yet, `up.sh` will launch the setup wizard
automatically before starting containers.

4. **Stop the services:**

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
├── down.sh                  # Stop all services
├── rebuild.sh               # Rebuild docker-compose.yml & .env only
├── scripts/
│   ├── setup.py             # Setup wizard logic
│   ├── rebuild_compose.py   # Generates docker-compose.yml & .env
│   ├── service_deps.py      # Service dependency map
│   ├── ensure_venv.sh       # Python venv bootstrap (sourced by shell scripts)
│   ├── requirements.txt     # Python dependencies
│   └── push_images.py       # Push images to registry
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
| `./rebuild.sh` | Regenerate `docker-compose.yml` and `.env` without starting containers |
| `./export_databases.sh` | Backup PostgreSQL and MySQL databases |
| `./flush_redis_keys.sh` | Clear Redis cache |

## Configuration

The system is configured through:

1. **`config.yml`** - Main configuration file listing enabled services and settings. Generated by `./setup.sh` or copied from `config.yml.example`.
2. **`.secrets.yml`** - Auto-generated secrets (Canvas encryption keys, etc.). Not committed to version control.
3. **`.env` / `.env.template`** - Environment variables consumed by Docker Compose. The `.env` file is regenerated automatically by `rebuild_compose.py` from the template and `config.yml` values -- do not edit it by hand.
4. **`docker-compose-include.yml`** - Per-service Docker Compose fragments assembled into the final `docker-compose.yml` at build time.

To reconfigure the server, either edit `config.yml` directly or re-run `./setup.sh`.

## Development

To work on individual services:

1. Navigate to the service directory (e.g., `cd ope-smc`)
2. Make changes to Dockerfile or configuration
3. Rebuild with `./up.sh b`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is open source. See individual service directories for specific licensing information.

## Support

- GitHub Issues: [https://github.com/open-prison-education/ope-server/issues](https://github.com/open-prison-education/ope-server/issues)
