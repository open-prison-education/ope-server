# OPE NTP

Network Time Protocol server for the Open Prison Education platform.

## Overview

Provides time synchronization services using Chrony, allowing all OPE services and client devices to maintain accurate system time.

## Features

- Chrony-based NTP server
- Runs without privileged mode
- Configurable upstream NTP servers

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 123 | UDP | NTP service |

## Usage

Enable the service:

```bash
touch ope-ntp/.enabled
./up.sh
```

## Technical Details

- **Base Image:** Alpine 3.9.4
- **NTP Server:** Chrony
- **Source:** Based on [cturra/docker-ntp](https://github.com/cturra/docker-ntp)
