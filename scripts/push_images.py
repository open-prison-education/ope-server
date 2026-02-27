#!/usr/bin/env python3
"""Push Docker images for all enabled services to Docker Hub."""

import os
import sys

import yaml

from service_deps import resolve_services

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = os.path.join(BASE_DIR, "config.yml")


def main():
    if not os.path.isfile(CONFIG_PATH):
        print("ERROR: No config.yml found. Run ./setup.sh first.")
        sys.exit(1)

    with open(CONFIG_PATH, "r") as f:
        config = yaml.safe_load(f) or {}

    user_services = config.get("services", [])
    resolved = resolve_services(user_services)

    for svc in sorted(resolved):
        svc_dir = os.path.join(BASE_DIR, svc)
        if not os.path.isdir(svc_dir):
            continue
        image = f"operepo/{svc}:release"
        print(f"Pushing {image} ...")
        ret = os.system(f"docker push {image}")
        if ret != 0:
            print(f"  WARNING: push failed for {image}")

    print("\nFinished!")


if __name__ == "__main__":
    main()
