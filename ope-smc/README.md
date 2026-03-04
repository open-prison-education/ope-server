# OPE SMC (Student Management Console)

Student Management Console for the Open Prison Education platform.

## Overview

SMC is the central management interface for OPE, providing tools to manage student accounts, content, and integration with Canvas LMS and OPE Laptops.

## Features

- **User Management:** Import and manage student accounts
- **Document Upload:** Upload documents directly to Canvas
- **Video Management:** Pull YouTube videos for offline conversion
- **Media Library:** Organize and manage media content
- **Document Library:** Central document repository
- **PDF Conversion:** Convert web links to PDF files
- **Canvas Integration:** Sync content with Canvas LMS

## Technical Details

- **Base Image:** Alpine 3.18
- **Framework:** Web2py
- **Port:** 8000

## Configuration

The SMC domain is derived from the `domain` setting in `config.yml`
(e.g. `smc.<domain>`). No separate configuration is needed.

## Usage

Enable SMC in `config.yml` (or via the interactive setup wizard `./setup.sh`):

```yaml
services:
  - ope-smc
```

Dependencies (`ope-redis`, `ope-postgresql`) are resolved automatically.
Then start services:

```bash
./up.sh
```
