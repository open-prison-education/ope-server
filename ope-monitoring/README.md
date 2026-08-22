# ope-monitoring

Grafana-based observability stack providing infrastructure monitoring and
web analytics for OPE Server. Derives traffic insights from nginx gateway
access logs and monitors host/container health, with full air-gap support.

## Components

| Service      | Image                        | Port  | Purpose                           |
|-------------|------------------------------|-------|-----------------------------------|
| Prometheus  | `prom/prometheus:v3.14.0`    | 9090  | Metrics storage (TSDB, 1yr)       |
| Loki        | `grafana/loki:3.7.6`         | 3100  | Log aggregation (30 days)         |
| Alloy       | `grafana/alloy:v1.18.1`     | 12345 | Collection agent (metrics + logs) |
| Grafana     | `grafana/grafana:13.2.0`     | 3000  | Dashboards and alerting UI        |
| Alertmanager| `prom/alertmanager:v0.34.0`  | 9093  | Alert routing and deduplication   |

## Directory Structure

```
ope-monitoring/
├── docker-compose-include.yml    # Compose fragment (5 services)
├── networks-include.yml          # Defines 'monitoring' network
├── init_dirs.sh                  # Creates data dirs with correct ownership
├── templates/                    # Source configs with <PLACEHOLDER> tokens
│   ├── prometheus.yml
│   ├── config.alloy
│   ├── loki-config.yml
│   ├── alertmanager.yml
│   ├── alert-rules.yml
│   └── monitoring-vhost.conf
├── generated/                    # Rendered by scripts/rebuild_compose.py
│   └── (same filenames as templates/)
├── scripts/
│   └── export_aggregates.sh     # Offline per-vhost aggregate export
└── grafana/
    ├── dashboards/               # Provisioned JSON dashboards
    │   ├── host-metrics.json
    │   ├── container-metrics.json
    │   ├── service-uptime.json
    │   └── traffic-by-site.json
    └── provisioning/
        ├── datasources/datasources.yml
        └── dashboards/dashboards.yml
```

## Quick Start

```bash
# 1. Ensure monitoring is in the service list in config.yml
#    (it is included by default)

# 2. Create data directories (requires root or sudo)
sudo ./ope-monitoring/init_dirs.sh /ope/monitoring

# 3. Rebuild config to render templates
./scripts/rebuild.sh

# 4. Bring up the stack
./up.sh
```

Grafana will be available at `https://monitoring.<DOMAIN>`.

## Configuration

All settings are in `config.yml` under `settings:`:

| Setting                | Default               | Description                          |
|-----------------------|-----------------------|--------------------------------------|
| `facility_id`         | `default`             | Machine-readable facility identifier |
| `facility_name`       | `Default Facility`    | Human-readable facility name         |
| `monitoring_data_root`| `/ope/monitoring`     | Data directory for all services      |
| `grafana_admin_pw`    | (falls back to it_pw) | Grafana admin password               |
| `prometheus_retention`| `365d`                | Prometheus TSDB retention period     |
| `loki_retention`      | `720h`                | Loki log retention (30 days)         |
| `alert_email`         | (required)            | Email for alert notifications        |
| `central_metrics_url` | (empty, disabled)     | Central Prometheus remote_write URL  |
| `central_loki_url`    | (empty, disabled)     | Central Loki push URL                |

After changing settings, run `./scripts/rebuild.sh` and restart the stack.

## Data Directories

Created by `init_dirs.sh` under `<monitoring_data_root>` (default `/ope/monitoring`):

| Directory      | UID:GID      | Service      |
|---------------|--------------|--------------|
| `prometheus/` | 65534:65534  | Prometheus   |
| `alertmanager/`| 65534:65534 | Alertmanager |
| `loki/`       | 10001:10001  | Loki         |
| `grafana/`    | 472:472      | Grafana      |
| `alloy/`      | 0:0          | Alloy        |
| `geoip/`      | 0:0          | GeoIP DB     |

## Centralization

Two modes for feeding data to a central monitoring instance:

### Connected: Remote Push

Set `central_metrics_url` and/or `central_loki_url` in `config.yml`. Alloy
will push to both local and central destinations simultaneously. Rebuild and
restart to activate.

### Air-Gapped: Sneakernet Export

```bash
# Export yesterday's per-vhost aggregates as CSV + JSON
./ope-monitoring/scripts/export_aggregates.sh

# Export last 7 days to a USB drive
./ope-monitoring/scripts/export_aggregates.sh --days 7 --output-dir /media/usb/exports
```

See [docs/MONITORING.md](../docs/MONITORING.md) for full centralization documentation.

## Dashboards

| Dashboard          | Source     | Shows                                       |
|-------------------|------------|---------------------------------------------|
| Host & Containers | Prometheus | CPU, memory, disk, network, container states|
| Uptime & Probes   | Prometheus | HTTP probe status, TLS expiry, latency      |
| Traffic by Site   | Loki+Prom  | Page views, top pages, referrers, geo       |

All dashboards are local JSON (no grafana.com imports that require internet).

## Alerts

Configured in `templates/alert-rules.yml`:
- Container restart loops
- Memory > 90% (no swap on this host)
- Disk > 80%
- HTTP probe failures (per vhost)
- TLS certificate expiry < 21 days
- 5xx error rate spikes

Alerts route to `alert_email` via Alertmanager and are visible in the Grafana UI.

## GeoIP

The traffic analytics pipeline requires `GeoLite2-City.mmdb` for geographic
lookups. Without it, infrastructure monitoring still works but geographic panels
show "Unknown."

Place the database at the project root and `init_dirs.sh` will install it, or
copy it directly to `<monitoring_data_root>/geoip/GeoLite2-City.mmdb`.

Refresh quarterly from https://github.com/P3TERX/GeoLite.mmdb or https://www.maxmind.com/en/geolite2/signup (free).

## Template System

Files in `templates/` use `<PLACEHOLDER>` tokens (e.g. `<DOMAIN>`,
`<FACILITY_ID>`) that are replaced by `scripts/rebuild_compose.py` during
build. Conditional blocks gate features on optional settings:

```
// #IF <CENTRAL_METRICS_URL>
...rendered only when central_metrics_url is configured...
// #ELSE
...rendered when it is not configured...
// #ENDIF <CENTRAL_METRICS_URL>
```

Never edit files in `generated/` directly — they are overwritten on rebuild.
