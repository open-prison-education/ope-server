# Offline Deployment Guide

This guide is for **site operators** who have received the OPE Server files and
need to set up the server on a machine **without internet access**.

You should have received these files:

| File | Contents |
|------|----------|
| `ope-server-offline.tar.gz` | OPE Server scripts, configuration, and bundled Python runtime |
| Image archives (`ope-canvas.tar.gz`, `ope-smc.tar.gz`, ...) | Pre-built Docker container images, one archive per service group. Older bundles ship a single `ope-images.tar.gz` instead. |

Published releases are on the repository's GitHub **Releases** page, named
`yy.mm.dd.build` (for example `26.11.6.0`). Each release also includes
`SHA256SUMS`, so you can check the downloads before moving them:

```bash
sha256sum -c SHA256SUMS --ignore-missing
```

`manifest.json` lists every archive. An entry with `"omitted": true` is not
attached to the release (it was too large for GitHub). Download that file
from the `location` URL and put it with the other archives before Step 2.

If you do not have these files, you may prepare them using
the [Offline Distribution Guide](OFFLINE_DISTRIBUTION.md).

---

## Before You Start

The target machine needs **Docker** installed. Everything else is included in
the files you received.

| Requirement | Minimum Version |
|-------------|-----------------|
| Docker Engine | 20.10 or later |
| Docker Compose | v2.0 or later |

To check if Docker is installed:

```bash
docker --version
docker compose version
```

If Docker is not installed, see the
[Docker installation steps](DEPLOYMENT.md#2-install-docker) in the Deployment
Guide. Docker itself does not require internet access to install if you have
the `.deb` packages available offline.

---

## Step 1: Extract the OPE Server Files

Copy all the files into one directory on the target machine (via USB drive,
shared network drive, etc.), then extract:

```bash
tar -xzf ope-server-offline.tar.gz
cd ope-server
```

---

## Step 2: Load the Docker Images

Stay in `ope-server`. The image archives are in the directory you copied the
files into, one level above this one. Load every archive from there:

```bash
for f in ../*.tar.gz; do
  [ "$(basename "$f")" = "ope-server-offline.tar.gz" ] && continue
  docker load -i "$f"
done
```

The shell is still inside `ope-server` after the loop. The retag command
below and `./setup.sh` in Step 3 run from here.

This may take several minutes depending on the number and size of images.
You can verify the images loaded correctly:

```bash
docker images | grep open-prison-education
```

You should see entries like `ghcr.io/open-prison-education/ope-canvas`,
`ghcr.io/open-prison-education/ope-gateway`, etc.

> **Upgrading from an older installation?** If the machine already has Docker
> images under the old `operepo/*` name, retag them instead of re-downloading:
> ```bash
> ./scripts/retag_images.sh
> ```
> Run with `--dry-run` first to preview the changes. See the
> [Deployment Guide](DEPLOYMENT.md#migrating-docker-images-from-old-registry)
> for details.

---

## Step 3: Run the Setup Wizard

```bash
./setup.sh
```

The wizard walks you through the key settings:

| Setting | What it controls |
|---------|-----------------|
| **Domain** | Base name for service URLs (default `ed`, giving `canvas.ed`, `smc.ed`, etc.) |
| **IP address** | The server's network IP (auto-detected if you leave it blank) |
| **IT password** | Administrator password for Canvas, PostgreSQL, and other services |
| **Office password** | Password for SMC / office login |
| **Services** | Which applications to enable (Canvas, SMC, Khan Academy, etc.) |

The wizard writes a `config.yml` file. You can re-run `./setup.sh` at any time
to change settings, or edit `config.yml` directly.

---

## Step 4: Start the Services

```bash
./up.sh
```

This starts all the services you selected during setup. It may take a few
minutes for all containers to come up. When Canvas is enabled and
`canvas_production` has no tables, `ope-canvas-init` creates the schema
before web and jobs start. That first run can take much longer. A database
that already has tables is left unchanged. To upgrade the server from an older
Canvas version to the current one, see [Canvas backup, restore, and upgrade](CANVAS_BACKUP_RESTORE.md).

To confirm everything is running:

```bash
docker ps
```

You should see containers listed for each enabled service (e.g. `ope-canvas`,
`ope-gateway`, `ope-dns`, etc.).

---

## Step 5: Access the Services

Once the services are running, open a web browser on a computer connected to
the same network as the server and navigate to:

- **Canvas LMS:** `https://canvas.ed`
- **Student Management Console:** `https://smc.ed`

For this to work, client machines need to use the OPE server as their DNS
server. The simplest approach is to configure your network's DHCP server to
distribute the OPE server's IP as the DNS server. This way, all machines on
the network can reach `canvas.ed`, `smc.ed`, and other services automatically.

For detailed instructions (including manual DNS setup per machine), see the
[Accessing Services Guide](ACCESSING_SERVICES.md).

> **SSL certificate warning:** Your browser will show a certificate warning the
> first time you visit. This is normal for an offline deployment. Click
> **Advanced** and then **Proceed** (or **Accept the Risk**) to continue. Your
> connection is still encrypted. See
> [SSL Certificate Warnings](ACCESSING_SERVICES.md#ssl-certificate-warnings)
> for more information.

---

## Stopping and Restarting

```bash
# Stop all services
./down.sh

# Start services again
./up.sh
```

Your data (databases, uploaded files, etc.) is preserved between stops and
starts.

---

## Reconfiguring

To change settings or enable/disable services:

```bash
# Option 1: Re-run the setup wizard
./setup.sh
./up.sh

# Option 2: Edit config.yml directly
nano config.yml
./up.sh
```

---

## Troubleshooting

### Services won't start

```bash
docker compose logs
```

Check the output for error messages. Common fixes:

- **Restart Docker:** `sudo systemctl restart docker`, then `./up.sh`
- **Check disk space:** `df -h` (services need significant storage)
- **Check memory:** `free -h` (minimum 8 GB RAM recommended)

### Cannot reach services in the browser

1. Verify the services are running: `docker ps`
2. Check that the client machine's DNS is set to the OPE server's IP
3. Try accessing directly from the server itself:
   ```bash
   curl -H "Host: canvas.ed" --insecure https://localhost:443
   ```

### 503 error in the browser

The gateway started before the backend service was ready. Restart it:

```bash
docker restart ope-gateway
```

For more troubleshooting steps, see the
[Deployment Guide](DEPLOYMENT.md#troubleshooting).

---

## Related Guides

- [Accessing Services](ACCESSING_SERVICES.md) -- DNS setup, remote access, SSL warnings
- [Deployment Guide](DEPLOYMENT.md) -- Full deployment reference (Docker install, backups, SSL, etc.)
- [Canvas backup, restore, and upgrade](CANVAS_BACKUP_RESTORE.md) -- Copy Canvas, put it back, or upgrade the server from an older Canvas version
- [Offline Distribution Guide](OFFLINE_DISTRIBUTION.md) -- For IT staff: how to build the offline bundle
