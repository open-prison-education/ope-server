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

Configure Canvas settings in `.env`:

```
CANVAS_DEFAULT_DOMAIN=canvas.<DOMAIN>
LMS_ACCOUNT_NAME=<Institution Name>
TIME_ZONE=<Timezone>
CANVAS_LOGIN_PROMPT=<Login prompt text>
```

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 3000 | HTTP | Canvas web interface |

## Related Services

- **ope-postgresql:** Database backend
- **ope-redis:** Cache and session storage
- **ope-canvas-rce:** Rich Content Editor
- **ope-canvas-mathman:** Math equation rendering

## Usage

Enable the service:

```bash
touch ope-canvas/.enabled
./up.sh
```

## Initial Setup

1. Access Canvas at `https://canvas.<your-domain>`
2. Complete the setup wizard
3. Create an admin account

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
