#!/usr/bin/env python3
"""
Rebuild docker-compose.yml and .env from config.yml + .secrets.yml.

Reads the unified config, resolves service dependencies, assembles
docker-compose.yml from per-service docker-compose-include.yml fragments,
and populates .env from .env.template with the configured values.
"""

import os
import sys
import shutil

import yaml

import glob as _glob

from service_deps import (
    resolve_services,
    detect_ip,
    generate_secret,
    generate_secret_32,
    generate_penpot_secret,
)

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = os.path.join(BASE_DIR, "config.yml")
SECRETS_PATH = os.path.join(BASE_DIR, ".secrets.yml")
ENV_TEMPLATE = os.path.join(BASE_DIR, ".env.template")
ENV_FILE = os.path.join(BASE_DIR, ".env")

# ---------------------------------------------------------------------------
# Docker-compose template header
# ---------------------------------------------------------------------------

DC_HEADER = """\
##### Open Prison Education - Docker Environment #####
# NOTE - This file gets rebuilt, make changes to docker-compose-include.yml file
#           in individual container directories and run scripts/rebuild_compose.py directly
#           or through scripts/rebuild.sh
#
# Start docker containers by running this command from the main folder:
#        ./up.sh
#
# Stop containers by running this command from the main folder:
#        ./down.sh
#
# START OF docker-compose.yml
<VOLUMES>

<NETWORKS>

services:

"""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_config():
    if not os.path.isfile(CONFIG_PATH):
        print("ERROR: No config.yml found.")
        print("       Run ./setup.sh first to configure the server.")
        sys.exit(1)
    with open(CONFIG_PATH, "r") as f:
        return yaml.safe_load(f) or {}


def load_or_create_secrets():
    """Load .secrets.yml, creating it with auto-generated values if missing."""
    if os.path.isfile(SECRETS_PATH):
        with open(SECRETS_PATH, "r") as f:
            secrets = yaml.safe_load(f) or {}
    else:
        secrets = {}

    changed = False
    if not secrets.get("canvas_secret"):
        secrets["canvas_secret"] = generate_secret()
        changed = True
    if not secrets.get("canvas_enc_secret"):
        secrets["canvas_enc_secret"] = generate_secret_32()
        changed = True
    if not secrets.get("canvas_sign_secret"):
        secrets["canvas_sign_secret"] = generate_secret_32()
        changed = True
    if not secrets.get("penpot_secret_key"):
        secrets["penpot_secret_key"] = generate_penpot_secret()
        changed = True

    if changed:
        fd = os.open(SECRETS_PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            yaml.dump(secrets, f, default_flow_style=False, sort_keys=False)
        print("Secrets auto-generated and saved to .secrets.yml")

    return secrets


def fallback(val, default=""):
    """Return *val* as a string, falling back to *default* when val is None."""
    return str(val) if val is not None else str(default)


def build_replacement_values(settings, secrets):
    """Build the placeholder -> value mapping used in compose and .env files."""
    domain = fallback(settings.get("domain"), "ed")
    ip = fallback(settings.get("ip"), "") or detect_ip()

    values = {
        "<DOMAIN>": domain,
        "<IP>": ip,
        "<VOLUMES>": "",
        "<VOLUMES_ROOT>": fallback(settings.get("volumes_root"), "./volumes"),
        "<NETWORK_MODE>": fallback(settings.get("network_mode"), "bridge"),
        "<CANVAS_SECRET>": fallback(secrets.get("canvas_secret"), ""),
        "<CANVAS_ENC_SECRET>": fallback(secrets.get("canvas_enc_secret"), ""),
        "<CANVAS_SIGN_SECRET>": fallback(secrets.get("canvas_sign_secret"), ""),
        "<IT_PW>": fallback(settings.get("it_pw"), "changeme"),
        "<OFFICE_PW>": fallback(settings.get("office_pw"), "changeme"),
        "<LMS_ACCOUNT_NAME>": fallback(settings.get("lms_account_name"), "Open Prison Education"),
        "<TIME_ZONE>": fallback(settings.get("time_zone"), "Pacific Time (US & Canada)"),
        "<CANVAS_LOGIN_PROMPT>": fallback(
            settings.get("canvas_login_prompt"),
            "Student ID (default is s + DOC number - s113412)",
        ),
        "<CANVAS_DEFAULT_DOMAIN>": f"canvas.{domain}",
        "<SMC_DEFAULT_DOMAIN>": f"smc.{domain}",
        "<IS_ONLINE>": fallback(settings.get("is_online"), 0),
        "<DNS_EXTRAS>": fallback(settings.get("dns_extras"), ""),
        "<ACME_AUTH_CODE>": fallback(settings.get("acme_auth_code"), "ZZZZ"),
        "<CANVAS_RCE_DEFAULT_DOMAIN>": f"rce.{domain}",
        "<CANVAS_MATHMAN_DEFAULT_DOMAIN>": f"mathman.{domain}",
        "<NTP_SERVERS>": fallback(settings.get("ntp_servers"), "time.windows.com"),
        "<ALERT_EMAIL>": fallback(settings.get("alert_email"), "alert@correctionsed.com"),
        "<CERT_NAME>": fallback(settings.get("cert_name"), "default"),
        "<PENPOT_SECRET_KEY>": fallback(secrets.get("penpot_secret_key"), ""),
        "<NETWORKS>": "",
        "<FACILITY_ID>": fallback(settings.get("facility_id"), "default"),
        "<FACILITY_NAME>": fallback(settings.get("facility_name"), "Default Facility"),
        "<GRAFANA_ADMIN_PW>": fallback(settings.get("grafana_admin_pw"), fallback(settings.get("it_pw"), "changeme")),
        "<MONITORING_DATA_ROOT>": fallback(settings.get("monitoring_data_root"), "/ope/monitoring"),
        "<PROMETHEUS_RETENTION>": fallback(settings.get("prometheus_retention"), "365d"),
        "<LOKI_RETENTION>": fallback(settings.get("loki_retention"), "720h"),
        "<CENTRAL_METRICS_URL>": fallback(settings.get("central_metrics_url"), ""),
        "<CENTRAL_LOKI_URL>": fallback(settings.get("central_loki_url"), ""),
    }
    return values


def process_service_folder(service_dir):
    """Read docker-compose-include.yml, volumes-include.yml, and
    networks-include.yml for a service.
    Returns (compose_fragment, volume_names, network_names)."""
    compose_fragment = ""
    volume_names = []
    network_names = ""

    dc_path = os.path.join(service_dir, "docker-compose-include.yml")
    if not os.path.isfile(dc_path):
        print(f"  WARNING: No docker-compose-include.yml in {service_dir}")
        return compose_fragment, volume_names, network_names

    try:
        with open(dc_path, "r") as f:
            compose_fragment = f.read()
    except Exception as e:
        print(f"  ERROR reading {dc_path}: {e}")
        return compose_fragment, volume_names, network_names

    compose_fragment += "\n\n"

    vol_path = os.path.join(service_dir, "volumes-include.yml")
    if os.path.isfile(vol_path):
        try:
            with open(vol_path, "r") as f:
                for line in f:
                    line = line.strip()
                    comment_pos = line.find("#")
                    if comment_pos > -1:
                        line = line[:comment_pos].strip()
                    if line:
                        volume_names.append(line)
        except Exception as e:
            print(f"  ERROR reading {vol_path}: {e}")

    net_path = os.path.join(service_dir, "networks-include.yml")
    if os.path.isfile(net_path):
        try:
            with open(net_path, "r") as f:
                network_names = f.read()
        except Exception as e:
            print(f"  ERROR reading {net_path}: {e}")

    return compose_fragment, volume_names, network_names


import re


def _process_conditional_blocks(content, replacement_values):
    """Process #IF/#ELSE/#ENDIF conditional blocks in template content.

    Syntax (comment style adapts to the file type):
      // #IF <PLACEHOLDER>    (or # #IF <PLACEHOLDER> for YAML/shell)
      ...kept when <PLACEHOLDER> is non-empty...
      // #ELSE
      ...kept when <PLACEHOLDER> is empty...
      // #ENDIF <PLACEHOLDER>

    The #ELSE section is optional. Directive lines themselves are always removed
    from the output regardless of which branch is kept."""
    pattern = re.compile(
        r'^[ \t]*(?://|#)\s*#IF\s+(<[A-Z_]+>)\s*\n'
        r'(.*?)'
        r'(?:^[ \t]*(?://|#)\s*#ELSE\s*\n(.*?))?'
        r'^[ \t]*(?://|#)\s*#ENDIF\s+\1\s*\n',
        re.MULTILINE | re.DOTALL,
    )

    def _replace(m):
        placeholder = m.group(1)
        if_block = m.group(2)
        else_block = m.group(3) or ""
        value = replacement_values.get(placeholder, "")
        if value:
            return if_block
        return else_block

    return pattern.sub(_replace, content)


def render_monitoring_templates(replacement_values):
    """Render ope-monitoring/templates/* into ope-monitoring/generated/,
    applying the same placeholder substitution used for compose files.
    Scoped to templates/ so it doesn't clobber files that other services
    render inside their containers at startup.

    Also deploys the monitoring vhost override to the gateway volume so
    nginx serves X-Robots-Tag on the Grafana subdomain."""
    templates_dir = os.path.join(BASE_DIR, "ope-monitoring", "templates")
    generated_dir = os.path.join(BASE_DIR, "ope-monitoring", "generated")

    if not os.path.isdir(templates_dir):
        return

    os.makedirs(generated_dir, exist_ok=True)

    domain = replacement_values.get("<DOMAIN>", "ed")
    volumes_root = replacement_values.get("<VOLUMES_ROOT>", "./volumes")

    for src_path in _glob.glob(os.path.join(templates_dir, "*")):
        if not os.path.isfile(src_path):
            continue
        filename = os.path.basename(src_path)
        with open(src_path, "r") as f:
            content = f.read()
        content = _process_conditional_blocks(content, replacement_values)
        for key, value in replacement_values.items():
            content = content.replace(key, value)
        dst_path = os.path.join(generated_dir, filename)
        with open(dst_path, "w") as f:
            f.write(content)
        print(f"  Rendered ope-monitoring/generated/{filename}")

    # Deploy the monitoring vhost override into the gateway volume so
    # nginx picks it up without manual intervention.
    vhost_src = os.path.join(generated_dir, "monitoring-vhost.conf")
    if os.path.isfile(vhost_src):
        vhost_dir = os.path.join(BASE_DIR, volumes_root, "gateway", "vhost.d")
        if os.path.isabs(volumes_root):
            vhost_dir = os.path.join(volumes_root, "gateway", "vhost.d")
        os.makedirs(vhost_dir, exist_ok=True)
        vhost_dst = os.path.join(vhost_dir, f"monitoring.{domain}")
        shutil.copy(vhost_src, vhost_dst)
        print(f"  Deployed vhost override → {vhost_dst}")


def rebuild_env(replacement_values):
    """Rebuild .env from .env.template with placeholder replacement."""
    if not os.path.isfile(ENV_TEMPLATE):
        print("WARNING: No .env.template found -- skipping .env generation")
        return

    shutil.copy(ENV_TEMPLATE, ENV_FILE)

    with open(ENV_FILE, "r") as f:
        content = f.read()

    for key, value in replacement_values.items():
        content = content.replace(key, value)

    with open(ENV_FILE, "w") as f:
        f.write(content)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    config = load_config()
    secrets = load_or_create_secrets()

    settings = config.get("settings") or {}
    user_services = config.get("services") or []

    resolved = resolve_services(user_services)

    replacement_values = build_replacement_values(settings, secrets)

    print("Rebuilding docker compose...")

    dc_out = DC_HEADER
    volume_list = []
    network_list = []

    for service_name in sorted(resolved):
        service_dir = os.path.join(BASE_DIR, service_name)
        if not os.path.isdir(service_dir):
            print(f"  WARNING: directory {service_name}/ not found, skipping")
            continue

        print(f"  Processing {service_name}")
        fragment, volumes, networks = process_service_folder(service_dir)
        dc_out += fragment
        for vol in volumes:
            if vol not in volume_list:
                print(f"    Adding volume: {vol[:-1]} from {service_name} ")
                volume_list.append(vol)
        if networks.strip():
            print(f"    Adding networks: {networks.strip()[:-1]} from {service_name}")
            network_list.append(networks)

    if volume_list:
        vol_section = "volumes:\n"
        for vol in volume_list:
            vol_section += f"    {vol}\n"
        replacement_values["<VOLUMES>"] = vol_section

    if network_list:
        networks = "networks:\n"
        for network in network_list:
            networks += f"    {network}"
            if not network.endswith("\n"):
                networks += "\n"
        replacement_values["<NETWORKS>"] = networks

    for key, value in replacement_values.items():
        dc_out = dc_out.replace(key, value)

    compose_path = os.path.join(BASE_DIR, "docker-compose.yml")
    with open(compose_path, "w") as f:
        f.write(dc_out)

    if "ope-monitoring" in resolved:
        print("\nRendering monitoring templates...")
        render_monitoring_templates(replacement_values)

    rebuild_env(replacement_values)

    print("\nRebuild Compose Complete.")


if __name__ == "__main__":
    main()
