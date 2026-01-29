# OPE Let's Encrypt

Automatic SSL certificate management for the Open Prison Education platform.

## Overview

Provides automatic SSL certificate provisioning and renewal using Let's Encrypt (for online deployments).

## Features

- Automatic certificate generation
- Certificate renewal
- Integration with OPE Gateway

## Configuration

Configure the ACME authorization code in `.env`:

```
ACME_AUTH_CODE=<your-auth-code>
```

## Usage

Enable the service (requires internet access):

```bash
touch ope-letsencrypt/.enabled
./up.sh
```

## Notes

This service requires internet access to communicate with Let's Encrypt servers. For offline deployments, use self-signed certificates instead.
