# Accessing OPE Services

This guide explains how to access Canvas LMS and other OPE services after deployment.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Available Services](#available-services)
- [Access Methods](#access-methods)
  - [Air-Gapped / Local Network](#air-gapped--local-network)
  - [Remote Access via Public IP](#remote-access-via-public-ip)
- [SSL Certificate Warnings](#ssl-certificate-warnings)
- [Troubleshooting](#troubleshooting)

## Architecture Overview

OPE Server uses a domain-based routing architecture:

```
                                    ┌─────────────────┐
                                    │   ope-gateway   │
    Incoming Request ──────────────►│  (nginx-proxy)  │
    Host: canvas.ed                 │   Ports 80/443  │
                                    └────────┬────────┘
                                             │
                          Routes based on Host header
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    │                        │                        │
                    ▼                        ▼                        ▼
             ┌────────────┐          ┌────────────┐          ┌────────────┐
             │ ope-canvas │          │  ope-smc   │          │ ope-kalite │
             │ canvas.ed  │          │  smc.ed    │          │ kalite.ed  │
             └────────────┘          └────────────┘          └────────────┘
```

**Key components:**

| Component | Purpose |
|-----------|---------|
| **ope-gateway** | Nginx reverse proxy that routes traffic based on the `Host` header |
| **ope-dns** | Local DNS server for air-gapped environments (resolves `.ed` domains) |
| **Service containers** | Register themselves via `VIRTUAL_HOST` environment variable |

## Available Services

The default domain suffix is `.ed` (configurable via `DOMAIN` in `.env`).

| Service | Default Domain(s) | Description |
|---------|-------------------|-------------|
| Canvas LMS | `canvas.ed`, `ed` | Learning Management System |
| SMC | `smc.ed`, `admin.ed`, `videos.ed`, `media.ed` | Student Management Console |
| Canvas RCE | `rce.ed` | Rich Content Editor for Canvas |
| Canvas Mathman | `mathman.ed` | Math equation rendering |
| KA Lite | `kalite.ed`, `khan.ed` | Khan Academy offline content |
| GCF | `gcf.ed`, `gcflearnfree.ed` | GCFLearnFree content |
| FOG | `fog.ed`, `fogserver.ed` | System imaging server |
| Git | `git.ed` | Git server |
| JS Bin | `jsbin.ed` | JavaScript code playground |
| CodeCombat | `codecombat.ed` | Coding education game |
| freeCodeCamp | `freecodecamp.ed` | freeCodeCamp offline content |
| RACHEL | `rachel.ed` | RACHEL offline educational content |

**Note:** Only services with a `.enabled` file in their directory will be active. See [Installation](DEPLOYMENT.md#3-enable-services) for details.

## Access Methods

### Air-Gapped / Local Network

In an air-gapped or local network environment, configure client machines to use the OPE server as their DNS server. This is the recommended approach for lab/classroom deployments.

#### Option 1: Configure DHCP (Recommended)

Configure your network's DHCP server to distribute:
- DNS Server: `<OPE_SERVER_IP>` (e.g., `10.48.1.202`)

This way, all client machines automatically resolve `.ed` domains without manual configuration.

#### Option 2: Manual DNS Configuration

On each client machine, set the DNS server to the OPE server's IP address:

**Windows:**
1. Open Network Connections
2. Right-click your network adapter → Properties
3. Select "Internet Protocol Version 4 (TCP/IPv4)" → Properties
4. Select "Use the following DNS server addresses"
5. Enter the OPE server's IP address

**Linux:**
```bash
# Edit /etc/resolv.conf or use NetworkManager
nameserver <OPE_SERVER_IP>
```

**macOS:**
1. System Preferences → Network
2. Select your connection → Advanced → DNS
3. Add the OPE server's IP address

#### Access Services

Once DNS is configured, simply open a browser and navigate to:
- `https://canvas.ed` - Canvas LMS
- `https://smc.ed` - Student Management Console

### Remote Access via Public IP

For remote access over the internet (e.g., cloud deployments), you cannot use the `ope-dns` service. Instead, use one of these methods:

#### Option 1: Edit Local Hosts File (Recommended)

Add entries to your local machine's hosts file mapping domains to the server's **public IP**.

**Linux / macOS** (`/etc/hosts`):
```
<PUBLIC_IP> canvas.ed
<PUBLIC_IP> smc.ed
<PUBLIC_IP> rce.ed
<PUBLIC_IP> mathman.ed
```

**Windows** (`C:\Windows\System32\drivers\etc\hosts`):
```
<PUBLIC_IP> canvas.ed
<PUBLIC_IP> smc.ed
<PUBLIC_IP> rce.ed
<PUBLIC_IP> mathman.ed
```

Replace `<PUBLIC_IP>` with your server's actual public IP address (e.g., `203.0.113.50`).

To find your server's public IP:
```bash
curl ifconfig.me
```

After editing the hosts file, access services via:
- `https://canvas.ed`
- `https://smc.ed`

#### Option 2: Use a Real Domain

For production deployments, configure a real domain:

1. Register a domain (e.g., `myschool.org`)
2. Create DNS A records pointing to your server's public IP:
   - `canvas.myschool.org` → `<PUBLIC_IP>`
   - `smc.myschool.org` → `<PUBLIC_IP>`
3. Update the `VIRTUAL_HOST` environment variables in the docker-compose files
4. Run `./rebuild.sh` and `./up.sh` to apply changes

#### Why You Can't Just Use the IP Address

The nginx gateway routes requests based on the `Host` header. When you access `https://203.0.113.50` directly, the browser sends `Host: 203.0.113.50`, which doesn't match any configured virtual host, resulting in a 503 error.

The hosts file approach works because:
1. Your browser resolves `canvas.ed` → `54.71.244.206` (via hosts file)
2. Browser connects to `54.71.244.206` but sends `Host: canvas.ed`
3. Nginx matches `canvas.ed` and routes to the correct service

## SSL Certificate Warnings

OPE Server generates self-signed SSL certificates by default. When accessing services, your browser will display a security warning.

**To proceed:**
- **Chrome:** Click "Advanced" → "Proceed to canvas.ed (unsafe)"
- **Firefox:** Click "Advanced" → "Accept the Risk and Continue"
- **Safari:** Click "Show Details" → "visit this website"

For production environments, consider:
- Using Let's Encrypt (configure `ope-letsencrypt` service)
- Installing your own trusted certificates in `volumes/gateway/certs/`

## Troubleshooting

### Cannot Connect to Services

1. **Verify containers are running:**
   ```bash
   docker ps
   ```

2. **Check gateway is listening:**
   ```bash
   curl -I http://localhost:80
   ```

3. **Test with Host header:**
   ```bash
   curl -H "Host: canvas.ed" --insecure https://localhost:443
   ```

### 503 Service Unavailable

This usually means nginx can't route to the backend. Check:
- The service container is running
- The `VIRTUAL_HOST` environment variable is set correctly
- Run `docker logs ope-gateway` for details

### SSL Certificate Errors (Not Warnings)

If you see "INVALID CERT SETUP" instead of the application:

```bash
# Check for empty certificate directories
ls -la volumes/gateway/certs/

# Remove empty domain directories (they interfere with cert lookup)
sudo rm -rf volumes/gateway/certs/canvas.ed
sudo rm -rf volumes/gateway/certs/smc.ed

# Restart gateway
docker restart ope-gateway
```

### Firewall Issues

Ensure ports 80 and 443 are open:

```bash
# Check UFW (Ubuntu)
sudo ufw status

# Allow ports if needed
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

For cloud providers (AWS, GCP, Azure), also check security group / firewall rules in the cloud console.

---

For more information, see the main [Deployment Guide](DEPLOYMENT.md).
