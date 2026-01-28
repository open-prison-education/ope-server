# Hostenter

Docker utility container for host system access.

## Overview

Provides privileged access to the Docker host system for debugging and maintenance tasks.

## Usage

```bash
docker run -it --privileged --pid=host hostenter
```

## Warning

This container runs with elevated privileges. Use with caution and only for debugging purposes.

## Technical Details

- **Base Image:** Alpine
- **Capabilities:** Privileged mode, host PID namespace
