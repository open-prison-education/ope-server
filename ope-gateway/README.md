# OPE Gateway

Nginx-based reverse proxy and SSL termination for the Open Prison Education platform.

## Overview

The gateway service routes incoming HTTP/HTTPS traffic to the appropriate backend services and handles SSL certificate management.

## Configuration

SSL certificates are stored in `/etc/nginx/certs/` volume.

Custom nginx configuration can be added via:
- `gateway.conf` - Main gateway configuration
- `uploads.conf` - Upload size limits
- `proxy.conf` - Proxy settings

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 80 | HTTP | Redirects to HTTPS |
| 443 | HTTPS | Main entry point |

## Volumes

| Path | Description |
|------|-------------|
| `/etc/nginx/certs` | SSL certificates |
| `/etc/nginx/conf.d` | Additional configuration |
| `/usr/share/nginx/html` | Static files |

## Usage

Enable the service:

```bash
touch ope-gateway/.enabled
./up.sh
```

