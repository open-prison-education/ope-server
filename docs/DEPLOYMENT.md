# OPE Server Deployment Guide

This guide covers the complete deployment process for the Open Prison Education (OPE) Server on a Linux environment.

## Table of Contents

- [System Requirements](#system-requirements)
- [Pre-Installation](#pre-installation)
- [Installation](#installation)
- [Configuration](#configuration)
- [Service Management](#service-management)
- [Backup and Restore](#backup-and-restore)
- [Troubleshooting](#troubleshooting)

## System Requirements

### Hardware

- **CPU:** 4+ cores recommended
- **RAM:** Minimum 16GB, 32GB+ recommended
- **Storage:** 500GB+ (varies based on content)
- **Network:** Static IP address recommended

### Software

- **Operating System:** Ubuntu 20.04 LTS or later (recommended)
- **Docker Engine:** 20.10 or later
- **Docker Compose:** v2.0 or later
- **Python:** 3.6 or later
- **Git:** 2.x or later

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

### 4. Install Python 3

```bash
sudo apt install python3 python3-pip -y
```

## Installation

### 1. Clone Repository

```bash
git clone https://github.com/open-prison-education/ope-server
cd ope-server
```

### 2. Configure Environment

```bash
# Copy the template
cp .env.template .env

# Edit configuration
nano .env
```

Key settings to configure:

| Setting | Description |
|---------|-------------|
| `PUBLIC_IP` | Server's IP address (auto-detected if blank) |
| `DOMAIN` | Main services domain
| `IT_PW` | IT administrator password |
| `OFFICE_PW` | Office user password used for SMC login 

### 3. Enable Services

Create `.enabled` files in each service directory you want to run:

```bash
# Core services (recommended)
touch ope-gateway/.enabled
touch ope-dns/.enabled
touch ope-postgresql/.enabled
touch ope-redis/.enabled
touch ope-canvas/.enabled
touch ope-canvas-mathman/.enabled
touch ope-canvas-rce/.enabled
touch ope-smc/.enabled
touch ope-letsencrypt/.enabled

# Optional services
touch ope-ntp/.enabled        # Time synchronization
touch ope-fog/.enabled        # System imaging
touch ope-kalite/.enabled     # Khan Academy content
touch ope-gcf/.enabled        # GCFLearnFree content
```

### 4. Generate Docker Compose

```bash
./rebuild.sh
```

### 5. Start Services

```bash
./up.sh
```

## Configuration

### SSL Certificates

SSL certificates are automatically generated on first run. For custom certificates:

1. Place certificates in `volumes/gateway/certs/`
2. Update `ope-gateway/docker-compose-include.yml`

### DNS Configuration

The `ope-dns` service provides local DNS resolution. Configure additional entries in `.env`:

```
DNS_EXTRAS=extra1.domain,extra2.domain
```

### Canvas LMS Setup

After first startup:

1. Access Canvas at `https://canvas.<your-domain>`
2. Complete the initial setup wizard
3. Create/access admin account
`
## Service Management

### Start All Services

```bash
./up.sh
```

### Stop All Services

```bash
./down.sh
```

### Rebuild and Start

```bash
./up.sh b
```

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
0 2 * * * /path/to/ope-server/export_databases.sh
```

### Manual Backup

```bash
./export_databases.sh
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
./fix_role_overrides_migration_error.sh
```

#### Redis Cache Issues

```bash
./flush_redis_keys.sh
```

### Getting Help

- Check container logs: `docker compose logs [service-name]`
- GitHub Issues: https://github.com/open-prison-education/ope-server/issues

---
