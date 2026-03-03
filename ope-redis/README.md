# OPE Redis

Redis cache server for the Open Prison Education platform.

## Overview

Provides in-memory caching and session storage for Canvas LMS and other OPE services.

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 6379 | TCP | Redis connections |

## Volumes

| Path | Description |
|------|-------------|
| `/data` | Persistent Redis data |

## Maintenance

Clear the Redis cache:

```bash
./flush_redis_keys.sh
```

## Usage

This service is a **dependency** that is enabled automatically when a service
that requires it (e.g. `ope-canvas`, `ope-smc`) is listed in `config.yml`.
There is no need to enable it manually.
