# OPE DNS

DNS server for the Open Prison Education platform using dnsmasq.

## Overview

Provides local DNS resolution for all OPE services, allowing domain-based access to services within the network.

## Configuration

Custom DNS entries can be set via the `dns_extras` field in `config.yml`:

```yaml
settings:
  dns_extras: "custom1.domain,custom2.domain"
```

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 53 | TCP/UDP | DNS queries |

## Usage

This is a **core service** that is always enabled automatically. No manual
configuration is needed -- it is included in every deployment.

