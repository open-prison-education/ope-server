# OPE FOG

FOG Project imaging server for the Open Prison Education platform.

## Overview

FOG (Free Open-source Ghost) is a computer imaging solution that allows deployment and management of system images across multiple computers. This container runs the FOG server within Docker for the OPE project.

## Features

- Network-based system imaging (PXE boot)
- Multicast image deployment
- Image management and storage
- Host registration and inventory
- Task scheduling

## Requirements

### Host System

The Docker host requires specific kernel modules for TFTP, NFS, and FTP:

```bash
# TFTP support
modprobe nf_conntrack_tftp
modprobe nf_nat_tftp

# FTP/NFS support
modprobe nf_conntrack_ftp
modprobe nf_conntrack_netbios_ns
modprobe nfs
modprobe nfsd
```

**Note:** The `up.sh` script automatically loads these modules on supported systems.

## Network Configuration

The container runs in **bridged** network mode (not host mode) with static ports for NAT forwarding compatibility.

### Exposed Ports

| Port | Protocol | Service |
|------|----------|---------|
| 80, 443 | TCP | Web interface |
| 20, 21 | TCP | FTP |
| 69 | UDP | TFTP |
| 111 | TCP/UDP | RPC |
| 2049 | TCP/UDP | NFS |
| 4045 | TCP/UDP | NFS Lock |
| 7000-7030 | UDP | TFTP transfer |

## Container Privileges

The container requires elevated privileges:

```yaml
privileged: true
cap_add:
  - NET_ADMIN
  - SYS_ADMIN
```

## Volumes

| Path | Description |
|------|-------------|
| `/var/lib/mysql` | MySQL database |
| `/images` | System images |
| `/backup` | Backup storage |

## Configuration

On startup, `update_fog_ip.py` automatically configures:
- FOG settings with current IP
- MySQL database entries
- TFTP boot configuration

## Usage

Enable FOG in `config.yml` (or via the interactive setup wizard `./setup.sh`):

```yaml
services:
  - ope-fog
```

Then start services:

```bash
./up.sh
```

## Troubleshooting

### TFTP Issues

Ensure iptables rules allow TFTP traffic:

```bash
iptables -A INPUT -p udp -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p udp --dport 69 -m state --state NEW -j ACCEPT
```

### Container NAT

The container uses masquerading for proper UDP packet routing:

```bash
iptables -t nat -A POSTROUTING -j MASQUERADE
```

## Resources

- FOG Project: https://fogproject.org/
