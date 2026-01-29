# OPE DNS

DNS server for the Open Prison Education platform using dnsmasq.

## Overview

Provides local DNS resolution for all OPE services, allowing domain-based access to services within the network.

## Configuration

DNS entries are configured through the `.env` file:

```
DNS_EXTRAS=custom1.domain,custom2.domain
```

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 53 | TCP/UDP | DNS queries |

## Usage

Enable the service:

```bash
touch ope-dns/.enabled
./up.sh
```

