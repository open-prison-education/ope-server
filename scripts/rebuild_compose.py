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

from service_deps import (
    CORE_SERVICES,
    SERVICE_DEPS,
    resolve_services,
    detect_ip,
    generate_secret,
    generate_secret_32,
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
#           in individual container directories and run rebuild_compose.py
#
# Start docker containers by running this command from the main folder:
#        docker-compose up -d
#
# Stop containers by running this command from the main folder:
#        docker-compose down
#
# START OF docker-compose.yml
<VOLUMES>


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

    if changed:
        with open(SECRETS_PATH, "w") as f:
            yaml.dump(secrets, f, default_flow_style=False, sort_keys=False)
        print("Secrets auto-generated and saved to .secrets.yml")

    return secrets


def build_replacement_values(settings, secrets):
    """Build the placeholder -> value mapping used in compose and .env files."""
    domain = settings.get("domain", "ed")
    ip = settings.get("ip", "") or detect_ip()

    values = {
        "<DOMAIN>": domain,
        "<IP>": ip,
        "<VOLUMES>": "",
        "<NETWORK_MODE>": settings.get("network_mode", "bridge"),
        "<CANVAS_SECRET>": secrets.get("canvas_secret", ""),
        "<CANVAS_ENC_SECRET>": secrets.get("canvas_enc_secret", ""),
        "<CANVAS_SIGN_SECRET>": secrets.get("canvas_sign_secret", ""),
        "<IT_PW>": str(settings.get("it_pw", "changeme")),
        "<OFFICE_PW>": str(settings.get("office_pw", "changeme")),
        "<LMS_ACCOUNT_NAME>": settings.get("lms_account_name", "Open Prison Education"),
        "<TIME_ZONE>": settings.get("time_zone", "Pacific Time (US & Canada)"),
        "<CANVAS_LOGIN_PROMPT>": settings.get(
            "canvas_login_prompt",
            "Student ID (default is s + DOC number - s113412)",
        ),
        "<CANVAS_DEFAULT_DOMAIN>": f"canvas.{domain}",
        "<SMC_DEFAULT_DOMAIN>": f"smc.{domain}",
        "<IS_ONLINE>": str(settings.get("is_online", 0)),
        "<DNS_EXTRAS>": settings.get("dns_extras", ""),
        "<ACME_AUTH_CODE>": settings.get("acme_auth_code", "ZZZZ"),
        "<CANVAS_RCE_DEFAULT_DOMAIN>": f"rce.{domain}",
        "<CANVAS_MATHMAN_DEFAULT_DOMAIN>": f"mathman.{domain}",
        "<NTP_SERVERS>": settings.get("ntp_servers", "time.windows.com"),
        "<ALERT_EMAIL>": settings.get("alert_email", "alert@correctionsed.com"),
        "<CERT_NAME>": settings.get("cert_name", "default"),
    }
    return values


def process_service_folder(service_dir):
    """Read docker-compose-include.yml and volumes-include.yml for a service.
    Returns (compose_fragment, volume_names)."""
    compose_fragment = ""
    volume_names = []

    dc_path = os.path.join(service_dir, "docker-compose-include.yml")
    if not os.path.isfile(dc_path):
        print(f"  WARNING: No docker-compose-include.yml in {service_dir}")
        return compose_fragment, volume_names

    try:
        with open(dc_path, "r") as f:
            compose_fragment = f.read()
    except Exception as e:
        print(f"  ERROR reading {dc_path}: {e}")
        return compose_fragment, volume_names

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

    return compose_fragment, volume_names


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

    for service_name in sorted(resolved):
        service_dir = os.path.join(BASE_DIR, service_name)
        if not os.path.isdir(service_dir):
            print(f"  WARNING: directory {service_name}/ not found, skipping")
            continue

        print(f"  Processing {service_name}")
        fragment, volumes = process_service_folder(service_dir)
        dc_out += fragment
        for vol in volumes:
            if vol not in volume_list:
                print(f"    Volume: {vol}")
                volume_list.append(vol)

    if volume_list:
        vol_section = "volumes:\n"
        for vol in volume_list:
            vol_section += f"    {vol}\n"
        replacement_values["<VOLUMES>"] = vol_section

    for key, value in replacement_values.items():
        dc_out = dc_out.replace(key, value)

    compose_path = os.path.join(BASE_DIR, "docker-compose.yml")
    with open(compose_path, "w") as f:
        f.write(dc_out)

    rebuild_env(replacement_values)

    print("\nRebuild Compose Complete.")


if __name__ == "__main__":
    main()
