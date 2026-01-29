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
| **ope-hub** | Django-based SMC replacement (in development) |

## Prerequisites

- Linux server (Ubuntu 20.04+ recommended)
- Docker Engine 20.10+
- Docker Compose v2+
- Python 3.6+
- Minimum 16GB RAM (32GB+ recommended)
- 500GB+ storage (varies based on content)

## Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/operepo/ope-server.git
   cd ope-server
   ```

2. **Configure environment:**
   ```bash
   cp .env.template .env
   # Edit .env with your settings
See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed deployment instructions.   ```

3. **Enable desired services:**
   ```bash
   # Create .enabled file in each service folder you want to run
   touch ope-canvas/.enabled
   touch ope-canvas-mathman/.enabled
   touch ope-canvas-rce/.enabled
   touch ope-smc/.enabled
   touch ope-postgresql/.enabled
   touch ope-redis/.enabled
   touch ope-gateway/.enabled
   touch ope-dns/.enabled
   ```

4. **Start the services:**
   ```bash
   ./up.sh
   ```

5. **Stop the services:**
   ```bash
   ./down.sh
   ```

## Directory Structure

```
ope-server/
├── scripts/              # Python management scripts
│   ├── rebuild_compose.py   # Generates docker-compose.yml
│   ├── push_images.py       # Push images to registry
│   └── mgmt.py              # Management utilities
├── docs/                 # Documentation
├── ope-*/                # Individual service directories
├── .env.template         # Environment configuration template
├── up.sh                 # Start all enabled services
├── down.sh               # Stop all services
└── rebuild.sh            # Rebuild docker-compose.yml
```

## Management Commands

| Command | Description |
|---------|-------------|
| `./up.sh` | Start all enabled containers |
| `./up.sh b` | Build and start containers |
| `./up.sh auto` | Start with auto configuration |
| `./down.sh` | Stop all containers |
| `./rebuild.sh` | Regenerate docker-compose.yml |
| `./export_databases.sh` | Backup PostgreSQL and MySQL databases |
| `./flush_redis_keys.sh` | Clear Redis cache |

## Configuration

The system is configured through:

1. **`.env` file** - Main configuration (copy from `.env.template`)
2. **`.enabled` files** - Place in service folders to enable them
3. **`docker-compose-include.yml`** - Per-service Docker Compose configuration

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed deployment instructions.

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

- GitHub Issues: [https://github.com/operepo/ope-server/issues](https://github.com/operepo/ope-server/issues)
- Documentation: [https://github.com/operepo/ope](https://github.com/operepo/ope)
