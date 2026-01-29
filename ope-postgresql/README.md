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
./export_databases.sh
```

Backups are stored in `/var/lib/postgresql/data/backups/`.

## Usage

Enable the service:

```bash
touch ope-postgresql/.enabled
./up.sh
```
