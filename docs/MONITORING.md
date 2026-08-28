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

1. **Download** GeoLite2 City in MMDB format (not CSV):
   https://www.maxmind.com/en/accounts/current/geoip/downloads
   or https://github.com/P3TERX/GeoLite.mmdb (no sign up needed)


2. **Deploy** to the server:
   ```bash
   # Copy the new file into the geoip directory
   sudo cp GeoLite2-City.mmdb /ope/monitoring/geoip/GeoLite2-City.mmdb
   sudo chmod 644 /ope/monitoring/geoip/GeoLite2-City.mmdb

   # Restart Alloy to pick up the new database
   docker compose restart alloy
   ```

3. **Verify** in Grafana → Traffic by Site dashboard that geographic panels
   show data.

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

## Centralization

The stack is designed to either push metrics/logs to a central instance (when
connected) or export daily aggregates for sneakernet import (when air-gapped).
Both approaches preserve facility attribution via labels stamped at collection
time.

### Facility Labels

Every metric and log entry is automatically stamped with:
- `facility` — machine-readable ID (e.g. `corrections-dev`)
- `facility_name` — human-readable label (e.g. `Corrections Dev`)

These are configured in `config.yml` under `facility_id` and `facility_name`.

### Connected Mode (Remote Push)

For facilities with network connectivity to a central monitoring instance, add
these settings to `config.yml` and run `./scripts/rebuild.sh`:

```yaml
settings:
  # Central Prometheus endpoint accepting remote_write
  central_metrics_url: https://central-prometheus.example.com/api/v1/write
  # Central Loki endpoint accepting push
  central_loki_url: https://central-loki.example.com/loki/api/v1/push
```

When configured, Alloy will push to **both** local and central destinations.
The central Loki receives logs with `X-Scope-OrgID` set to the `facility_id`,
enabling multi-tenant partitioning. Local retention is unaffected — the facility
retains full self-contained monitoring even while pushing upstream.

To disable central push, remove (or empty) the URLs and rebuild. No data is
lost locally.

### Air-Gapped Mode (Sneakernet Export)

For facilities that cannot reach a central instance, use the export script to
produce daily per-vhost aggregate files:

```bash
# Export yesterday's aggregates (default)
./ope-monitoring/scripts/export_aggregates.sh

# Export the last 7 days
./ope-monitoring/scripts/export_aggregates.sh --days 7

# Custom output directory and format
./ope-monitoring/scripts/export_aggregates.sh \
  --output-dir /media/usb/exports \
  --format csv \
  --days 30
```

Output files are named `<facility_id>_<date>.{csv,json}` and contain per-vhost
daily totals: requests, page views, and status code breakdowns (2xx/3xx/4xx/5xx).

**CSV columns:**
`facility_id, date, host, requests, pageviews, status_2xx, status_3xx, status_4xx, status_5xx`

These lightweight aggregates (~1 KB per facility per day) are designed for easy
import into a central dashboard, spreadsheet, or data warehouse.

### Central Import

The exported files can be imported into a central Grafana instance using:
- Direct CSV import into PostgreSQL/SQLite for a central dashboard
- A script that posts the JSON records to a central API
- Manual review in any spreadsheet application

The export format is deliberately simple to avoid coupling the central system
to a specific technology choice.

---

## Dashboards

| Dashboard          | Data Source | Purpose                                          |
|-------------------|-------------|--------------------------------------------------|
| Host & Containers | Prometheus  | CPU, memory, disk, network, container states     |
| Uptime & Probes   | Prometheus  | HTTP probe status, TLS expiry, response times    |
| Traffic by Site   | Loki + Prom | Page views, top pages, referrers, user agents, geo |

All dashboards are provisioned as local JSON files (no internet-dependent
grafana.com imports) at `ope-monitoring/grafana/dashboards/`.
