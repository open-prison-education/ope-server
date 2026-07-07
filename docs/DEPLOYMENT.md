# OPE Server Deployment Guide

This guide covers the complete deployment process for the Open Prison Education (OPE) Server on a Linux environment.

## Table of Contents

- [System Requirements](#system-requirements)
- [Pre-Installation](#pre-installation)
- [Installation](#installation)
- [Configuration](#configuration)
- [Service Management](#service-management)
- [Backup and Restore](#backup-and-restore)
- [Public Deployment: Preventing Search Engine Crawling](#public-deployment-preventing-search-engine-crawling)
- [Migrating Docker Images from Old Registry](#migrating-docker-images-from-old-registry)
- [Troubleshooting](#troubleshooting)

**Related:**
- [Accessing Services Guide](ACCESSING_SERVICES.md) - How to access Canvas and other applications
- [Offline Deployment Guide](OFFLINE_DEPLOYMENT.md) - For site operators: deploying from pre-built files on an air-gapped machine
- [Offline Distribution Guide](OFFLINE_DISTRIBUTION.md) - For developers: building the offline bundle

## System Requirements

### Hardware

- **CPU:** 4+ cores recommended
- **RAM:** Minimum 8GB
- **Storage:** 500GB+ (varies based on content)
- **Network:** Static IP address recommended

### Software

- **Operating System:** Ubuntu 20.04 LTS or later (recommended)
- **Docker Engine:** 20.10 or later
- **Docker Compose:** v2.0 or later
- **Python:** 3.6 or later (not required on air-gapped targets)
- **Git:** 2.x or later (not required on air-gapped targets)

Note: Python and Git are only needed on the build machine. Air-gapped targets use a
pre-built tarball that includes a bundled Python runtime and all dependencies -- see the
[Offline Deployment Guide](OFFLINE_DEPLOYMENT.md).

## Pre-Installation

### 1. Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add current user to docker group
sudo usermod -aG docker $USER

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Log out and back in for group changes to take effect
```

### 3. Install Docker Compose

```bash
# Docker Compose is included with Docker Desktop
# For Linux servers, install the plugin:
sudo apt install docker-compose-plugin

# Verify installation
docker compose version
```

### 4. Install Python 3 (not required on air-gapped targets)

```bash
sudo apt install python3 python3-pip -y
```

## Installation

### 1. Clone Repository (not required on air-gapped targets)

```bash
git clone https://github.com/open-prison-education/ope-server
cd ope-server
```

### 2. Configure the Server

Run the interactive setup wizard:

```bash
./setup.sh
```

The wizard walks you through all settings and service selection, then writes
`config.yml` and `.secrets.yml`. Alternatively, copy the example config and
edit it by hand:

```bash
cp config.yml.example config.yml
nano config.yml
```

Key settings in `config.yml`:

| Setting | Description |
|---------|-------------|
| `domain` | Base domain for service subdomains (default `ed`, giving `canvas.ed`, `smc.ed`, etc.) |
| `ip` | Server's IP address (auto-detected if blank) |
| `it_pw` | IT administrator password (used for Canvas admin, PostgreSQL, etc.) |
| `office_pw` | Office user password (used for SMC login) |
| `is_online` | `1` if the server has internet access, `0` for offline / air-gapped |

Services are listed under the `services:` key. Core services (`ope-gateway`,
`ope-dns`) and dependencies (e.g. `ope-redis`, `ope-postgresql` for Canvas)
are resolved automatically -- you only need to list the services you want:

```yaml
services:
  - ope-canvas
  - ope-smc
```

See `config.yml.example` for the full list of available services and settings.

### 3. Start Services

```bash
./up.sh
```

This rebuilds `docker-compose.yml` and `.env` from `config.yml`, then starts
all configured containers. If `config.yml` does not exist yet, `up.sh` will
launch the setup wizard automatically.

### 4. Access Services

Once services are running, see the **[Accessing Services Guide](ACCESSING_SERVICES.md)** for detailed instructions on:
- Accessing Canvas, SMC, and other applications
- Configuring DNS for air-gapped environments
- Remote access via public IP
- Handling SSL certificate warnings

**Quick start (remote access):** If accessing over the internet, add entries to your local machine's `/etc/hosts` file:
```
<SERVER_PUBLIC_IP> canvas.ed
<SERVER_PUBLIC_IP> smc.ed
```

Then navigate to `https://canvas.ed` in your local machine's browser. For air-gapped/local network setups, see the full guide for DNS configuration.

## Configuration

### SSL Certificates

SSL certificates are automatically generated on first run. For custom certificates:

1. Place certificates in `volumes/gateway/certs/`
2. Update `ope-gateway/docker-compose-include.yml`

### DNS Configuration

The `ope-dns` service provides local DNS resolution for air-gapped environments. It uses dnsmasq and automatically resolves the configured domain (default `.ed`) to the server IP.

To add extra DNS records or dnsmasq options, set `dns_extras` in `config.yml`. The value is passed directly to the dnsmasq command line:

```yaml
settings:
  # Single option
  dns_extras: "-A /custom.local/192.168.1.100"

  # Multiple options
  dns_extras: "-A /internal.lab/10.0.0.50 -A /printer.local/10.0.0.25"
```

After editing, run `./up.sh` to apply the changes. See the [dnsmasq documentation](https://thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html) for available options.

## Service Management

### Start All Services

Pulls pre-built images from the registry and starts containers:

```bash
./up.sh
```

### Stop All Services

```bash
./down.sh
```

### Build Locally and Start

Builds images from source locally (instead of pulling from the registry), then starts containers:

```bash
./up.sh b
```

### Reconfigure

Re-run the interactive setup wizard to change settings or toggle services:

```bash
./setup.sh
./up.sh
```

Or edit `config.yml` directly and run `./up.sh`.

### View Logs

```bash
docker compose logs [service-name]
```

### Restart Individual Service

```bash
docker compose restart ope-canvas
```

## Backup and Restore

### Automated Backups

Add to crontab for daily backups at 2:00 AM:

```bash
crontab -e
# Add this line:
0 2 * * * /path/to/ope-server/scripts/export_databases.sh
```

### Manual Backup

```bash
./scripts/export_databases.sh
```

Backups are stored in:
- PostgreSQL: `/var/lib/postgresql/data/backups/`
- MySQL (FOG): `/var/lib/mysql/backups/`

### Restore Database

```bash
# PostgreSQL
docker compose exec ope-postgresql psql -U postgres -d canvas_production < backup.sql

# MySQL
docker compose exec ope-fog mysql < backup.sql
```

## Public Deployment: Preventing Search Engine Crawling

When deploying OPE Server on a public-facing network, you should prevent search engines from indexing and crawling the SMC application.

### Add Nginx Virtual Host Configuration

Create a file under `volumes/gateway/vhost.d/` named after your SMC domain. For example, if your domain is `smc.yourSchool.org`:

```bash
nano volumes/gateway/vhost.d/smc.yourSchool.org
```

Add the following content:

```nginx
## Prevent search engines from indexing/crawling ope-smc
add_header X-Robots-Tag "noindex, nofollow, nosnippet, noarchive" always;

## Start of configuration add by letsencrypt container
location ^~ /.well-known/acme-challenge/ {
    auth_basic off;
    auth_request off;
    allow all;
    root /usr/share/nginx/html;
    try_files $uri =404;
    break;
}
## End of configuration add by letsencrypt container
```

Replace `smc.yourSchool.org` with your actual SMC domain (i.e. `smc.<your-domain>`). Restart the gateway for the changes to take effect:

```bash
docker compose restart ope-gateway
```

## Migrating Docker Images from Old Registry

If you have an existing deployment with Docker images cached under the old
`operepo/*` Docker Hub namespace, you can retag them to the current
`ghcr.io/open-prison-education/*` registry without re-downloading:

```bash
# Preview what would be retagged (no changes made)
./scripts/retag_images.sh --dry-run

# Retag all operepo/* images to ghcr.io/open-prison-education/*
./scripts/retag_images.sh

# Retag and remove the old operepo/* tags
./scripts/retag_images.sh --remove-old
```

This is especially useful on air-gapped machines where re-pulling images from
the internet is not possible.

## Troubleshooting

### Common Issues

#### Containers Won't Start

```bash
# Check Docker status
sudo systemctl status docker

# View container logs
docker compose logs

# Rebuild containers
./up.sh b
```

#### Database Connection Errors

```bash
# Restart database containers
docker compose restart ope-postgresql ope-redis
```

#### Permission Issues

```bash
# Fix volume permissions
sudo chown -R 1000:1000 volumes/
```

#### Canvas Migration Errors

If you encounter `PG::UniqueViolation` errors:

```bash
./scripts/fix_role_overrides_migration_error.sh
```

#### Redis Cache Issues

```bash
./scripts/flush_redis_keys.sh
```

### Getting Help

- Check container logs: `docker compose logs [service-name]`
- GitHub Issues: https://github.com/open-prison-education/ope-server/issues

---
