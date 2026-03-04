# OPE PostgreSQL

PostgreSQL database server for the Open Prison Education platform.

## Overview

Provides the primary database backend for Canvas LMS and other OPE services requiring relational data storage.

## Databases

| Database | Description |
|----------|-------------|
| `canvas_production` | Main Canvas LMS database |
| `canvas_queue` | Canvas job queue database |
| `postgres` | System database |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 5432 | TCP | PostgreSQL connections |

## Volumes

| Path | Description |
|------|-------------|
| `/var/lib/postgresql/data` | Database files |

## Backup

Use the provided backup script:

```bash
./scripts/export_databases.sh
```

Backups are stored in `/var/lib/postgresql/data/backups/`.

## Usage

This service is a **dependency** that is enabled automatically when a service
that requires it (e.g. `ope-canvas`, `ope-smc`) is listed in `config.yml`.
There is no need to enable it manually.
