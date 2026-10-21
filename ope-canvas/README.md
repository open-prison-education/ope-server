# OPE Canvas

Canvas LMS for the Open Prison Education platform.

## Overview

Canvas is a learning management system (LMS) by Instructure, configured to run offline and integrate with the OPE project. It provides course management, assignments, grading, and communication tools for students and teachers.

## Features

- Course creation and management
- Assignment submission and grading
- Discussion boards
- Quiz and assessment tools
- Offline sync capabilities
- Integration with OPE SMC

## Configuration

Canvas settings are managed in `config.yml`:

```yaml
settings:
  domain: ed                  # canvas.<domain>
  lms_account_name: "Open Prison Education"
  time_zone: "Pacific Time (US & Canada)"
  canvas_login_prompt: "Student ID (default: s + DOC number e.g. s113412)"
```

Canvas encryption secrets are stored in `.secrets.yml` and auto-generated
on first run.

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 3000 | HTTP | Canvas web interface |

## Related Services

These containers are defined with Canvas and live under `ope-canvas/services/`:

- **ope-canvas-postgres:** Canvas-owned PostgreSQL 16
- **ope-canvas-redis:** Canvas-owned Redis 8.8
- **ope-canvas-rce:** Rich Content Editor
- **ope-canvas-mathman:** Math equation rendering
- **ope-canvas-init:** One-shot schema setup when `canvas_production` has no tables
- **ope-canvas-jobs:** Delayed jobs
- **ope-canvas-migrate:** Manual migrations (`--profile migrate`)

## Usage

Enable Canvas in `config.yml` (or via the interactive setup wizard `./setup.sh`):

```yaml
services:
  - ope-canvas
```

The Canvas-owned data and editor services are resolved automatically.
Build or import the pinned images, then start services:

```bash
./up.sh
```

`ope-canvas-init` runs before web and jobs. It creates the schema when
`canvas_production` has no tables, then exits. An existing schema is left
unchanged. To upgrade the server from an older Canvas version to the current
one, see `docs/CANVAS_BACKUP_RESTORE.md`.

## Initial Setup

1. Access Canvas at `https://canvas.<your-domain>`
2. Login with username: `admin@<your-domain>`, password: (the **it_pw** value set in `config.yml`)

---

## Technical Notes

### Sharding Configuration

The OPE Canvas implementation modifies the default sharding behavior to support offline sync between facilities:

- **Shard Range:** Modified from 10 trillion to 1 quintillion to accommodate facility IDs
- **Facility ID:** Auto-generated based on timestamp, stored in `volumes/canvas/tmp/db_sequence_range`
- **ID Structure:**
  - Max Value: `9,223,372,036,854,775,807` (64-bit max)
  - Shard Range: Last digit (supports ~10 shards)
  - School Range: 7 digits for facility ID (supports ~10 million facilities)
  - Local ID Range: 11 digits (~99 billion IDs per table)

### Facility ID Generation

Facility IDs are generated on first boot based on the current timestamp minus a base date (12/1/16). This provides approximately 19.5 years of unique IDs before rollover.

**Note:** Starting two Canvas servers at the exact same minute could result in ID conflicts. This is extremely unlikely in practice.

### Database Tables

The OPE audit system uses these tables for sync tracking:

- `ope_audit.import_actions` - Tracks imported changes from remote servers
- `ope_audit.export_log` - Tracks export operations
- `ope_audit.import_log` - Tracks import operations
