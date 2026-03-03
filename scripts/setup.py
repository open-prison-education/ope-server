#!/usr/bin/env python3
"""
OPE Server interactive setup wizard.

Guides the user through environment settings and service selection, resolves
dependencies, and writes config.yml + .secrets.yml.
"""

import os
import sys

import yaml

from service_deps import (
    CORE_SERVICES,
    SERVICE_CATALOG,
    SERVICE_DEPS,
    resolve_services,
    detect_ip,
    generate_secret,
    generate_secret_32,
)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = os.path.join(BASE_DIR, "config.yml")
SECRETS_PATH = os.path.join(BASE_DIR, ".secrets.yml")

DEFAULT_SETTINGS = {
    "domain": "ed",
    "ip": "",
    "is_online": 0,
    "it_pw": "changeme",
    "office_pw": "changeme",
    "time_zone": "Pacific Time (US & Canada)",
    "lms_account_name": "Open Prison Education",
    "canvas_login_prompt": "Student ID (default is s + DOC number - s113412)",
    "ntp_servers": "time.windows.com",
    "alert_email": "alert@correctionsed.com",
    "acme_auth_code": "ZZZZ",
    "cert_name": "default",
    "dns_extras": "",
    "network_mode": "bridge",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def prompt(label, default=""):
    """Prompt the user for a value, showing the current default."""
    display_default = str(default) if default != "" else ""
    if display_default:
        raw = input(f"  {label} [{display_default}]: ").strip()
    else:
        raw = input(f"  {label}: ").strip()
    return raw if raw else str(default)


def load_existing_config():
    """Load existing config.yml if present, returning (settings, services)."""
    if not os.path.isfile(CONFIG_PATH):
        return None, None
    with open(CONFIG_PATH, "r") as f:
        data = yaml.safe_load(f) or {}
    return data.get("settings", {}), data.get("services", [])


def load_existing_secrets():
    """Load existing .secrets.yml if present."""
    if not os.path.isfile(SECRETS_PATH):
        return {}
    with open(SECRETS_PATH, "r") as f:
        return yaml.safe_load(f) or {}


# ---------------------------------------------------------------------------
# Wizard steps
# ---------------------------------------------------------------------------

def wizard_settings(defaults):
    """Prompt the user for environment settings."""
    print("\nNetwork Settings:")
    settings = {}
    settings["domain"] = prompt("Domain", defaults.get("domain", DEFAULT_SETTINGS["domain"]))

    default_ip = defaults.get("ip", "") or detect_ip()
    settings["ip"] = prompt("Public IP (blank=auto-detect)", default_ip)

    settings["is_online"] = int(prompt(
        "Online mode (1=internet, 0=offline)",
        defaults.get("is_online", DEFAULT_SETTINGS["is_online"]),
    ))

    print("\nPasswords:")
    settings["it_pw"] = prompt("IT admin password", defaults.get("it_pw", DEFAULT_SETTINGS["it_pw"]))
    settings["office_pw"] = prompt("Office user password", defaults.get("office_pw", DEFAULT_SETTINGS["office_pw"]))

    print("\nCanvas LMS Settings:")
    settings["lms_account_name"] = prompt(
        "Institution name",
        defaults.get("lms_account_name", DEFAULT_SETTINGS["lms_account_name"]),
    )
    settings["canvas_login_prompt"] = prompt(
        "Login prompt",
        defaults.get("canvas_login_prompt", DEFAULT_SETTINGS["canvas_login_prompt"]),
    )
    settings["time_zone"] = prompt(
        "Timezone",
        defaults.get("time_zone", DEFAULT_SETTINGS["time_zone"]),
    )

    print("\nInfrastructure (Enter to keep defaults):")
    settings["alert_email"] = prompt(
        "Alert email",
        defaults.get("alert_email", DEFAULT_SETTINGS["alert_email"]),
    )
    settings["ntp_servers"] = prompt(
        "NTP servers",
        defaults.get("ntp_servers", DEFAULT_SETTINGS["ntp_servers"]),
    )
    settings["acme_auth_code"] = prompt(
        "ACME auth code for Let's Encrypt",
        defaults.get("acme_auth_code", DEFAULT_SETTINGS["acme_auth_code"]),
    )
    settings["cert_name"] = prompt(
        "SSL cert name",
        defaults.get("cert_name", DEFAULT_SETTINGS["cert_name"]),
    )
    settings["dns_extras"] = prompt(
        "Extra DNS options",
        defaults.get("dns_extras", DEFAULT_SETTINGS["dns_extras"]),
    )
    settings["network_mode"] = prompt(
        "Docker network mode",
        defaults.get("network_mode", DEFAULT_SETTINGS["network_mode"]),
    )

    return settings


def wizard_services(preselected=None):
    """Let the user toggle services and return the selected list."""
    # Build flat list of selectable services with display info
    items = []
    for group in SERVICE_CATALOG:
        for svc in group["services"]:
            items.append({
                "group": group["group"],
                "name": svc["name"],
                "description": svc["description"],
                "extra": svc.get("extra_deps_label", ""),
            })

    selected = set(preselected or [])

    while True:
        print("\nSelect services to enable (core: ope-gateway, ope-dns always included):\n")
        current_group = None
        for idx, item in enumerate(items, 1):
            if item["group"] != current_group:
                current_group = item["group"]
                print(f"  {current_group}:")
            mark = "X" if item["name"] in selected else " "
            extra = f"  ({item['extra']})" if item["extra"] else ""
            print(f"    {idx:>2}. [{mark}] {item['name']}: {item['description']}{extra}")

        print()
        raw = input("Toggle by number (comma-separated), 'a' for all, Enter to confirm: ").strip()
        if raw == "":
            break
        if raw.lower() == "a":
            if len(selected) == len(items):
                selected.clear()
            else:
                selected = {item["name"] for item in items}
            continue
        for part in raw.split(","):
            part = part.strip()
            if part.isdigit():
                num = int(part)
                if 1 <= num <= len(items):
                    name = items[num - 1]["name"]
                    if name in selected:
                        selected.discard(name)
                    else:
                        selected.add(name)

    return sorted(selected)


def ensure_secrets(existing_secrets):
    """Return secrets dict, auto-generating any missing values."""
    secrets = dict(existing_secrets)
    if not secrets.get("canvas_secret"):
        secrets["canvas_secret"] = generate_secret()
    if not secrets.get("canvas_enc_secret"):
        secrets["canvas_enc_secret"] = generate_secret_32()
    if not secrets.get("canvas_sign_secret"):
        secrets["canvas_sign_secret"] = generate_secret_32()
    return secrets


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    existing_settings, existing_services = load_existing_config()
    existing_secrets = load_existing_secrets()
    is_reconfig = existing_settings is not None

    print("=" * 50)
    if is_reconfig:
        print("  OPE Server Setup  (reconfigure)")
    else:
        print("  OPE Server Setup")
    print("=" * 50)

    settings_defaults = existing_settings if is_reconfig else DEFAULT_SETTINGS
    settings = wizard_settings(settings_defaults)

    if not settings["ip"]:
        settings["ip"] = detect_ip()
        if settings["ip"]:
            print(f"\n  Auto-detected IP: {settings['ip']}")

    preselected = existing_services if is_reconfig else []
    selected_services = wizard_services(preselected)

    resolved = resolve_services(selected_services)

    print("\nServices to be enabled (with auto-resolved dependencies):")
    for svc in sorted(resolved):
        tag = ""
        if svc in CORE_SERVICES:
            tag = " (core)"
        elif svc not in selected_services:
            parents = [s for s in selected_services if svc in SERVICE_DEPS.get(s, [])]
            if parents:
                tag = f" (dependency of {', '.join(parents)})"
        print(f"  - {svc}{tag}")

    print()
    confirm = input("Write config.yml? [Y/n]: ").strip().lower()
    if confirm not in ("", "y", "yes"):
        print("Aborted.")
        sys.exit(1)

    secrets = ensure_secrets(existing_secrets)

    config_data = {
        "services": selected_services,
        "settings": settings,
    }
    with open(CONFIG_PATH, "w") as f:
        yaml.dump(config_data, f, default_flow_style=False, sort_keys=False)
    print(f"Config saved to {CONFIG_PATH}")

    fd = os.open(SECRETS_PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        yaml.dump(secrets, f, default_flow_style=False, sort_keys=False)
    print(f"Secrets saved to {SECRETS_PATH}")

    print("\nRun ./up.sh to start services.")


if __name__ == "__main__":
    main()
