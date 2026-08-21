# Monitoring & Analytics

OPE Server includes a Grafana-based observability stack (`ope-monitoring`) that
provides both **infrastructure monitoring** (host metrics, container health,
uptime probes) and **web analytics** (traffic by subdomain, top pages,
referrers, geographic breakdown) derived from nginx gateway logs.

**Related:**
- [Offline Distribution Guide](OFFLINE_DISTRIBUTION.md) -- Building the offline bundle
- [Offline Deployment Guide](OFFLINE_DEPLOYMENT.md) -- Installing on air-gapped machines
- [Deployment Guide](DEPLOYMENT.md) -- Full deployment with internet access

---

## Architecture

```
Clients → ope-gateway (nginx)
               │
               ├── access.json.log ──► Alloy ──┬──► Loki (logs, 30-day retention)
               │                                ├──► Prometheus (metrics, 1-year retention)
               │                                └──► Alertmanager → email
Docker socket + /proc /sys ──► Alloy
               │
Grafana ◄── Prometheus + Loki
  (monitoring.<DOMAIN>)
```

| Component    | Image                         | Purpose                            |
|-------------|-------------------------------|------------------------------------|
| Prometheus  | `prom/prometheus:v3.14.0`     | Metrics storage (TSDB)             |
| Loki        | `grafana/loki:3.7.6`          | Log aggregation                    |
| Alloy       | `grafana/alloy:v1.18.1`       | Collection agent (metrics + logs)  |
| Grafana     | `grafana/grafana:13.2.0`      | Dashboards and alerting UI         |
| Alertmanager| `prom/alertmanager:v0.34.0`   | Alert routing and deduplication    |

All five images are pinned to explicit versions and mirrored to
`ghcr.io/open-prison-education/` for air-gapped deployments.

---

## Air-Gap Packaging

### Docker Images

The monitoring images are exported as a single tarball alongside the other
service groups:

```bash
# On the build machine (has internet):
./scripts/push_to_ghcr.sh          # Mirror upstream → GHCR
./scripts/export_images.sh         # Creates exported_images/ope-monitoring.tar.gz
```

On the target machine:

```bash
docker load < exported_images/ope-monitoring.tar.gz
```

If the target has images cached under the upstream names (`prom/*`,
`grafana/*`), retag them:

```bash
./scripts/retag_images.sh          # Retags to ghcr.io/open-prison-education/*
```

### GeoIP Database

The Alloy log pipeline uses MaxMind's GeoLite2-City database for geographic
lookups. This ~60 MB file must be present for the analytics pipeline to start
cleanly. Infrastructure monitoring (metrics, alerts) is unaffected by its
absence.

**Bundling for air-gap transfer:**

```bash
# On the build machine, with GeoLite2-City.mmdb at the project root:
./scripts/bundle_geoip.sh
# → exported_images/GeoLite2-City.mmdb
```

**Installing on the target:**

```bash
# Option A: init_dirs.sh auto-detects the file at the project root
cp GeoLite2-City.mmdb /path/to/ope-server/
./ope-monitoring/init_dirs.sh /ope/monitoring

# Option B: pass the path explicitly
./ope-monitoring/init_dirs.sh /ope/monitoring /path/to/GeoLite2-City.mmdb
```

The database is installed at `<MONITORING_DATA_ROOT>/geoip/GeoLite2-City.mmdb`
(default: `/ope/monitoring/geoip/GeoLite2-City.mmdb`).

### Grafana Phone-Home Disabled

Grafana is configured with all outbound telemetry and update checks disabled so
it does not stall or error on air-gapped networks:

- `GF_ANALYTICS_REPORTING_ENABLED=false`
- `GF_ANALYTICS_CHECK_FOR_UPDATES=false`
- `GF_ANALYTICS_CHECK_FOR_PLUGIN_UPDATES=false`
- `GF_NEWS_NEWS_FEED_ENABLED=false`

### Access Control

- Grafana sign-up is disabled (`GF_USERS_ALLOW_SIGN_UP=false`)
- Admin password is sourced from `grafana_admin_pw` in `config.yml` (falls back
  to `it_pw` when unset)
- The `monitoring.<DOMAIN>` vhost carries `X-Robots-Tag: noindex` to prevent
  search engine crawling on internet-connected deployments

---

## GeoIP Database Refresh

MaxMind updates GeoLite2-City biweekly (Tuesdays). The database degrades
gradually — after 3-6 months new IP allocations will resolve to the wrong
location or to "unknown." Refresh quarterly at minimum.

### Procedure

1. **Sign in** to your free MaxMind account:
   https://www.maxmind.com/en/accounts/current/geoip/downloads

2. **Download** GeoLite2 City in MMDB format (not CSV).

3. **Deploy** to the server:
   ```bash
   # Copy the new file into the geoip directory
   sudo cp GeoLite2-City.mmdb /ope/monitoring/geoip/GeoLite2-City.mmdb
   sudo chmod 644 /ope/monitoring/geoip/GeoLite2-City.mmdb

   # Restart Alloy to pick up the new database
   docker compose restart alloy
   ```

4. **Verify** in Grafana → Traffic by Site dashboard that geographic panels
   show data.

### Creating a MaxMind Account

1. Go to https://www.maxmind.com/en/geolite2/signup
2. Complete registration (free, no payment required)
3. Under Account → GeoIP Downloads, download "GeoLite2 City" → MMDB format
4. Optionally generate a license key for automated downloads (not needed for
   manual refresh on air-gapped sites)

---

## Known Limitations

### Requests vs. Visitors

Log-based analytics counts **HTTP requests**, not unique people. Without
cookies or JavaScript, "unique visitors" can only be approximated by counting
distinct client IPs per day. This is reasonable for cloud-hosted environments
but has important caveats:

- **Behind NAT (facility LANs):** All users behind a shared NAT gateway appear
  as a single IP. The "unique visitors" count collapses toward 1. Meaningful
  per-facility dimensions are subdomain, time of day, and source subnet — not
  visitor count.
- **Shared devices:** Multiple students on the same device are indistinguishable.
- **Static assets:** The pipeline filters by `content_type` to separate HTML
  page views from CSS/JS/image requests, but API calls and XHR remain counted.

### Geographic Data on Air-Gapped Sites

Grafana's **geomap panel** fetches basemap tiles from the internet and renders
blank when offline. The Traffic by Site dashboard uses a country/region table
and bar chart as the default geographic breakdown. The geomap panel can be
enabled per-site where `is_online=1`.

Additionally, on facility LANs where all traffic originates from private RFC1918
addresses, GeoIP lookups return no result — geographic panels will show
"Unknown." This is expected and not a misconfiguration.

### Retention Periods

| Store      | Default Retention | Config Key             |
|-----------|-------------------|------------------------|
| Prometheus | 365 days          | `prometheus_retention` |
| Loki       | 30 days (720h)    | `loki_retention`       |

Long-term "which site is busiest" trends come from Prometheus counters
(`nginx_requests_total{host,status}`) that survive well beyond Loki's log
retention. Adjust retention in `config.yml` and run `./scripts/rebuild.sh`.

---

## Dashboards

| Dashboard          | Data Source | Purpose                                          |
|-------------------|-------------|--------------------------------------------------|
| Host & Containers | Prometheus  | CPU, memory, disk, network, container states     |
| Uptime & Probes   | Prometheus  | HTTP probe status, TLS expiry, response times    |
| Traffic by Site   | Loki + Prom | Page views, top pages, referrers, user agents, geo |

All dashboards are provisioned as local JSON files (no internet-dependent
grafana.com imports) at `ope-monitoring/grafana/dashboards/`.
