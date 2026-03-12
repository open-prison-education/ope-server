"""
Service dependency map for OPE Server.

Shared by setup.py (wizard) and rebuild_compose.py (compose generator).
Dependencies are derived from `depends_on` and `links` in each service's
docker-compose-include.yml.
"""

CORE_SERVICES = ["ope-gateway", "ope-dns"]

# Maps each user-selectable service to the full list of services it requires.
# Core services are implicitly included for every deployment.
SERVICE_DEPS = {
    "ope-canvas": [
        "ope-gateway", "ope-dns", "ope-redis", "ope-postgresql",
        "ope-canvas-rce", "ope-canvas-mathman",
    ],
    "ope-canvas-rce": ["ope-dns"],
    "ope-canvas-mathman": ["ope-gateway", "ope-dns", "ope-redis"],
    "ope-smc": ["ope-gateway", "ope-dns", "ope-redis", "ope-postgresql"],
    "ope-kalite": ["ope-gateway", "ope-dns"],
    "ope-codecombat": ["ope-gateway", "ope-dns"],
    "ope-fog": ["ope-gateway", "ope-dns"],
    "ope-gcf": ["ope-gateway", "ope-dns"],
    "ope-freecodecamp": ["ope-gateway", "ope-dns"],
    "ope-jsbin": ["ope-gateway", "ope-dns"],
    "ope-git": ["ope-gateway", "ope-dns"],
    "ope-rachel": ["ope-gateway", "ope-dns"],
    "ope-websites": ["ope-gateway", "ope-dns"],
    "ope-ntp": [],
    "ope-letsencrypt": [],
    "ope-redis": ["ope-gateway", "ope-dns"],
    "ope-postgresql": ["ope-gateway", "ope-dns"],
}

# Services shown in the setup wizard, grouped by category.
# Only these are presented to the user for selection; dependencies and core
# services are resolved automatically.
SERVICE_CATALOG = [
    {
        "group": "Canvas LMS",
        "services": [
            {
                "name": "ope-canvas",
                "description": "Canvas LMS",
                "extra_deps_label": "+ redis, postgresql, canvas-rce, canvas-mathman",
            },
        ],
    },
    {
        "group": "Student Management",
        "services": [
            {
                "name": "ope-smc",
                "description": "Student Management Console (SMC)",
                "extra_deps_label": "+ redis, postgresql",
            },
        ],
    },
    {
        "group": "Educational Content",
        "services": [
            {"name": "ope-kalite", "description": "Khan Academy Lite"},
            {"name": "ope-gcf", "description": "GCFLearnFree"},
            {"name": "ope-freecodecamp", "description": "freeCodeCamp"},
            {"name": "ope-codecombat", "description": "CodeCombat"},
            {"name": "ope-rachel", "description": "RACHEL"},
        ],
    },
    {
        "group": "Developer Tools",
        "services": [
            {"name": "ope-jsbin", "description": "JS Bin"},
            {"name": "ope-git", "description": "Git Server (GitLab)"},
        ],
    },
    {
        "group": "Infrastructure",
        "services": [
            {"name": "ope-ntp", "description": "NTP Time Server"},
            {"name": "ope-letsencrypt", "description": "Let's Encrypt SSL"},
            {"name": "ope-fog", "description": "FOG Imaging"},
            {"name": "ope-websites", "description": "Approved Websites"},
        ],
    },
]


def resolve_services(selected):
    """Return the full de-duplicated set of services including all transitive
    dependencies and core services, given a list of user-selected service names."""
    resolved = set(CORE_SERVICES)
    queue = list(selected)
    while queue:
        svc = queue.pop()
        if svc in resolved:
            continue
        resolved.add(svc)
        for dep in SERVICE_DEPS.get(svc, []):
            if dep not in resolved:
                queue.append(dep)
    return resolved

import uuid
import socket
import subprocess

# Helper functions used in setup.py and rebuild_compose.py
def detect_ip():
    """Auto-detect the local IP address."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 0))
        return s.getsockname()[0]
    except Exception:
        try:
            out = subprocess.check_output(["hostname", "-i"])
            return out.decode().strip()
        except Exception:
            return ""
    finally:
        s.close()


def generate_secret():
    return str(uuid.uuid4()) + "000"


def generate_secret_32():
    return (str(uuid.uuid4()) + "000")[:32]