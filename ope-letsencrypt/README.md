# OPE Let's Encrypt

Automatic SSL certificate management for the Open Prison Education platform.

## Overview

Provides automatic SSL certificate provisioning and renewal using Let's Encrypt (for online deployments).

## Features

- Automatic certificate generation
- Certificate renewal
- Integration with OPE Gateway

## Configuration

Set the ACME authorization code in `config.yml`:

```yaml
settings:
  acme_auth_code: "<your-auth-code>"
```

## Usage

Enable Let's Encrypt in `config.yml` (or via the interactive setup wizard `./setup.sh`):

```yaml
services:
  - ope-letsencrypt
```

Then start services:

```bash
./up.sh
```

## Notes

This service requires internet access to communicate with Let's Encrypt servers. For offline deployments, use self-signed certificates instead.
