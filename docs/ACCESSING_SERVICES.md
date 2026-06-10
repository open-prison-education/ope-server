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
  - [Cannot Connect to Services](#cannot-connect-to-services)
  - [503 Service Temporarily Unavailable](#503-service-temporarily-unavailable)
  - ["INVALID CERT SETUP"](#invalid-cert-setup)

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

The default domain suffix is `.ed` (configurable via the `domain` setting in `config.yml`).

| Service | Default Domain(s) | Description |
|---------|-------------------|-------------|
| Canvas LMS | `canvas.ed` | Learning Management System |
| SMC | `smc.ed` | Student Management Console |
| Canvas RCE | `N/A` | Rich Content Editor for Canvas |
| Canvas Mathman | `N/A` | Math equation rendering |
| KA Lite | `kalite.ed`| Khan Academy offline content |
| GCF | `gcf.ed` | GCFLearnFree content |
| FOG | `fog.ed`| System imaging server |
| Git | `git.ed` | Git server |
| JS Bin | `jsbin.ed` | JavaScript code playground |
| CodeCombat | `codecombat.ed` | Coding education game |
| freeCodeCamp | `freecodecamp.ed` | freeCodeCamp offline content |
| RACHEL | `rachel.ed` | RACHEL offline educational content |
| Penpot | `penpot.ed` | Penpot open-source design platform |

**Note:** Only services listed in `config.yml` (and their automatically resolved dependencies) will be active. See the [Deployment Guide](DEPLOYMENT.md#2-configure-the-server) for details.

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
3. Update the `domain` setting in `config.yml` to your domain
4. Run `./up.sh` to apply changes

#### Why You Can't Just Use the IP Address

The nginx gateway routes requests based on the `Host` header. When you access `https://203.0.113.50` directly, the browser sends `Host: 203.0.113.50`, which doesn't match any configured virtual host, resulting in a 503 error.

The hosts file approach works because:
1. Your browser resolves `canvas.ed` → `<PUBLIC_IP>` (via hosts file)
2. Browser connects to `<PUBLIC_IP>` but sends `Host: canvas.ed`
3. Nginx matches `canvas.ed` and routes to the correct service

## SSL Certificate Warnings

When you access `https://canvas.ed` or `https://smc.ed` (especially via [remote access with a hosts file](#remote-access-via-public-ip)), your browser will show a certificate warning. This is expected.

### Why you see "Certificate not trusted" or "This root certificate is not trusted"

- **Using hosts file with `.ed` domains:** The names `canvas.ed` and `smc.ed` are not real public domains. Let's Encrypt can only issue certificates for domains that resolve in public DNS and pass its verification. So when you use a hosts file to point `canvas.ed` / `smc.ed` at your server's public IP, the gateway has no valid public certificate for those hostnames and falls back to a default self-signed certificate. Your system does not trust that certificate, so you see "Certificate not trusted" or "This root certificate is not trusted."
- **Self-signed default:** If the `ope-letsencrypt` service is not used, the gateway uses a self-signed certificate by default, which browsers also do not trust.

### How to proceed (accept the warning and continue)

You can safely continue to the site after accepting the warning:

- **Chrome:** Click **Advanced** → **Proceed to canvas.ed (unsafe)** (or the equivalent for smc.ed).
- **Firefox:** Click **Advanced** → **Accept the Risk and Continue**.
- **Safari:** Click **Show Details** → **visit this website**.

Your connection is still encrypted; the warning only means the certificate authority is not in your system's trust store.

### When you get a trusted certificate (no warning)

- **Real domain + Let's Encrypt:** Use [Option 2: Use a real domain](#option-2-use-a-real-domain) so that `canvas.myschool.org`, `smc.myschool.org`, etc. point to your server. Then Let's Encrypt can issue trusted certificates for those names.
- **Your own certificates:** Install your own trusted certificates in `volumes/gateway/certs/` and configure the gateway to use them.

> **Important:** If you are using `.ed` domains with a hosts file (not a real public domain), **do not enable the `ope-letsencrypt` service**. The letsencrypt companion cannot issue certificates for `.ed` domains and will create empty certificate directories that interfere with the gateway's cert lookup (causing "INVALID CERT SETUP" errors). To disable it, remove `ope-letsencrypt` from the `services` list in `config.yml`, then run:
> ```bash
> ./up.sh
> ```
> Only enable `ope-letsencrypt` when using real public domains that resolve in DNS.

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

4. **Check firewall / security groups:**
   ```bash
   sudo ufw status
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```
   For cloud providers (AWS, GCP, Azure), also verify security group / firewall rules in the cloud console.

### 503 Service Temporarily Unavailable

A **503** from nginx means the gateway received the request (e.g. for `smc.ed` or `canvas.ed`) but could not reach the backend container. Common causes: the service isn't running, or the gateway generated its config before the backend was ready.

1. **Confirm the service is enabled and running:**
   ```bash
   docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E 'ope-gateway|ope-smc|ope-canvas'
   ```
   If the service container is missing, make sure it is listed in `config.yml`
   under `services:`, then rebuild and start:
   ```bash
   ./up.sh
   ```

2. **Restart the gateway after backends are up.**
   The gateway generates its routing config from running containers. If it started before the backend was ready, it has no upstream for that host:
   ```bash
   docker restart ope-gateway
   ```

3. **Inspect logs:**
   ```bash
   docker logs ope-gateway 2>&1 | tail -50
   docker logs ope-smc 2>&1 | tail -50
   ```

4. **Quick connectivity test from the server:**
   ```bash
   curl -H "Host: smc.ed" --insecure -s -o /dev/null -w "%{http_code}" https://127.0.0.1:443/
   ```
   `502`/`503` = gateway routes but backend isn't responding. `200` (or `401` for Canvas) = backend is fine and the issue is client-side (hosts file, firewall).

### "INVALID CERT SETUP"

If you see **"INVALID CERT SETUP"** and *"Make sure the .CERT_NAME value is set or that a proper cert exists"* after clicking through the certificate warning, the gateway matched your host (e.g. `canvas.ed`) to an **incomplete certificate** instead of the working default cert.

**Root cause:** The `ope-letsencrypt` companion creates empty directories (`canvas.ed/`, `smc.ed/`, `mathman.ed/`, `rce.ed/`) in the certs volume when it tries (and fails) to get Let's Encrypt certificates for `.ed` domains. The gateway's cert-lookup matches these directory names as if they were cert files, finds no actual `.crt`/`.key` inside, and returns the error page.

**Fix:**

```bash
# 1. Stop ope-letsencrypt and remove it from config.yml services list
docker stop ope-letsencrypt
# Edit config.yml and remove ope-letsencrypt from the services list, then:
./up.sh

# 2. Remove the empty cert directories it created
docker exec ope-gateway rm -rf \
  /etc/nginx/certs/canvas.ed \
  /etc/nginx/certs/smc.ed \
  /etc/nginx/certs/mathman.ed \
  /etc/nginx/certs/rce.ed \
  /etc/nginx/certs/accounts

# 3. Confirm default cert exists (cert_name is set in config.yml, default: "default")
docker exec ope-gateway ls /etc/nginx/certs/default.crt /etc/nginx/certs/default.key

# 4. Restart gateway to regenerate config
docker restart ope-gateway
```

Then try `https://canvas.ed` again. You will still see a one-time certificate warning (see [SSL Certificate Warnings](#ssl-certificate-warnings)), but after proceeding the application should load.

---

For more information, see the main [Deployment Guide](DEPLOYMENT.md).
