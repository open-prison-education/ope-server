#!/bin/bash
# export_aggregates.sh — Export daily per-vhost traffic aggregates from Prometheus.
#
# Designed for air-gapped facilities where metrics cannot be pushed to a central
# instance. Produces CSV and JSON files suitable for sneakernet import into a
# central dashboard or data warehouse.
#
# Queries Prometheus for rolled-up counters (nginx_requests_total,
# nginx_pageviews_total) grouped by vhost. Exports are far more practical than
# shipping whole Prometheus TSDB snapshots or Loki chunk directories.
#
# Usage:
#   ./export_aggregates.sh [OPTIONS]
#
# Options:
#   -o, --output-dir DIR    Output directory (default: ./monitoring_exports)
#   -d, --days N            Number of days to export (default: 1, i.e. yesterday)
#   -p, --prometheus URL    Prometheus URL (default: http://localhost:9090)
#   -f, --facility ID       Override facility_id (auto-detected from Prometheus)
#   --format FORMAT         Output format: csv, json, both (default: both)
#   -h, --help              Show this help message

set -euo pipefail

PROMETHEUS_URL="http://localhost:9090"
OUTPUT_DIR="./monitoring_exports"
DAYS=1
FACILITY_ID=""
FORMAT="both"

usage() {
    sed -n '/^# Usage:/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \?//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        -d|--days)       DAYS="$2"; shift 2 ;;
        -p|--prometheus) PROMETHEUS_URL="$2"; shift 2 ;;
        -f|--facility)   FACILITY_ID="$2"; shift 2 ;;
        --format)        FORMAT="$2"; shift 2 ;;
        -h|--help)       usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is required but not found" >&2
    exit 1
fi

if ! curl -sf "${PROMETHEUS_URL}/-/healthy" &>/dev/null; then
    echo "ERROR: Cannot reach Prometheus at ${PROMETHEUS_URL}" >&2
    echo "       Is Prometheus running? Try: docker compose exec prometheus wget -qO- http://localhost:9090/-/healthy" >&2
    exit 1
fi

if [[ -z "$FACILITY_ID" ]]; then
    FACILITY_ID=$(curl -sf "${PROMETHEUS_URL}/api/v1/label/facility/values" \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0] if d.get('data') else 'unknown')" 2>/dev/null \
        || echo "unknown")
fi

mkdir -p "$OUTPUT_DIR"

query_prometheus() {
    local query="$1"
    local start="$2"
    local end="$3"
    local step="${4:-3600}"
    curl -sf --get "${PROMETHEUS_URL}/api/v1/query_range" \
        --data-urlencode "query=${query}" \
        --data-urlencode "start=${start}" \
        --data-urlencode "end=${end}" \
        --data-urlencode "step=${step}"
}

instant_query() {
    local query="$1"
    local time="$2"
    curl -sf --get "${PROMETHEUS_URL}/api/v1/query" \
        --data-urlencode "query=${query}" \
        --data-urlencode "time=${time}"
}

echo "Exporting monitoring aggregates for facility: ${FACILITY_ID}"
echo "  Prometheus: ${PROMETHEUS_URL}"
echo "  Days: ${DAYS}"
echo "  Output: ${OUTPUT_DIR}"
echo ""

for day_offset in $(seq "$DAYS" -1 1); do
    day_start=$(date -u -d "${day_offset} days ago 00:00:00" +%s 2>/dev/null \
        || date -u -v-${day_offset}d -j -f "%H:%M:%S" "00:00:00" +%s)
    day_end=$(( day_start + 86399 ))
    day_label=$(date -u -d "@${day_start}" +%Y-%m-%d 2>/dev/null \
        || date -u -r "${day_start}" +%Y-%m-%d)

    echo "Processing ${day_label}..."

    requests_json=$(instant_query \
        "sum by (host) (increase(nginx_requests_total[24h]))" \
        "${day_end}")

    pageviews_json=$(instant_query \
        "sum by (host) (increase(nginx_pageviews_total[24h]))" \
        "${day_end}")

    bytes_json=$(instant_query \
        "sum by (host) (increase(nginx_requests_total[24h]) * on(host) group_left avg by (host) (rate(nginx_requests_total[24h])))" \
        "${day_end}" 2>/dev/null || echo '{"data":{"result":[]}}')

    status_json=$(instant_query \
        "sum by (host, status) (increase(nginx_requests_total[24h]))" \
        "${day_end}")

    export_file="${OUTPUT_DIR}/${FACILITY_ID}_${day_label}"

    python3 - "$requests_json" "$pageviews_json" "$status_json" "$export_file" "$FACILITY_ID" "$day_label" "$FORMAT" <<'PYTHON'
import sys
import json
import csv
from collections import defaultdict

requests_raw = json.loads(sys.argv[1]) if sys.argv[1] else {"data": {"result": []}}
pageviews_raw = json.loads(sys.argv[2]) if sys.argv[2] else {"data": {"result": []}}
status_raw = json.loads(sys.argv[3]) if sys.argv[3] else {"data": {"result": []}}
export_file = sys.argv[4]
facility_id = sys.argv[5]
day_label = sys.argv[6]
fmt = sys.argv[7]

requests_by_host = {}
for r in requests_raw.get("data", {}).get("result", []):
    host = r["metric"].get("host", "unknown")
    val = float(r["value"][1])
    requests_by_host[host] = requests_by_host.get(host, 0) + val

pageviews_by_host = {}
for r in pageviews_raw.get("data", {}).get("result", []):
    host = r["metric"].get("host", "unknown")
    val = float(r["value"][1])
    pageviews_by_host[host] = pageviews_by_host.get(host, 0) + val

status_by_host = defaultdict(lambda: defaultdict(float))
for r in status_raw.get("data", {}).get("result", []):
    host = r["metric"].get("host", "unknown")
    status = r["metric"].get("status", "unknown")
    val = float(r["value"][1])
    status_by_host[host][status] += val

all_hosts = sorted(set(list(requests_by_host.keys()) + list(pageviews_by_host.keys())))

if not all_hosts:
    print(f"  No data for {day_label}")
    sys.exit(0)

records = []
for host in all_hosts:
    status_breakdown = dict(status_by_host.get(host, {}))
    record = {
        "facility_id": facility_id,
        "date": day_label,
        "host": host,
        "requests": int(round(requests_by_host.get(host, 0))),
        "pageviews": int(round(pageviews_by_host.get(host, 0))),
        "status_2xx": int(round(sum(v for k, v in status_breakdown.items() if k.startswith("2")))),
        "status_3xx": int(round(sum(v for k, v in status_breakdown.items() if k.startswith("3")))),
        "status_4xx": int(round(sum(v for k, v in status_breakdown.items() if k.startswith("4")))),
        "status_5xx": int(round(sum(v for k, v in status_breakdown.items() if k.startswith("5")))),
    }
    records.append(record)

if fmt in ("json", "both"):
    json_path = export_file + ".json"
    with open(json_path, "w") as f:
        json.dump({
            "facility_id": facility_id,
            "date": day_label,
            "exported_at": __import__("datetime").datetime.utcnow().isoformat() + "Z",
            "vhosts": records,
        }, f, indent=2)
    print(f"  Written: {json_path}")

if fmt in ("csv", "both"):
    csv_path = export_file + ".csv"
    fieldnames = ["facility_id", "date", "host", "requests", "pageviews",
                  "status_2xx", "status_3xx", "status_4xx", "status_5xx"]
    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(records)
    print(f"  Written: {csv_path}")

print(f"  {day_label}: {len(all_hosts)} vhosts, {sum(r['requests'] for r in records)} total requests")
PYTHON

done

echo ""
echo "Export complete. Files in: ${OUTPUT_DIR}/"
ls -la "${OUTPUT_DIR}/"* 2>/dev/null | tail -20
echo ""
echo "Transfer these files to the central instance for import."
