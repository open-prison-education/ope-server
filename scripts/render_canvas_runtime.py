#!/usr/bin/env python3
"""Render Canvas runtime YAML into a gitignored host directory."""
from __future__ import annotations

import os
import pathlib
import stat

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "ope-canvas" / "runtime"
DST = ROOT / "ope-canvas" / "runtime-rendered"


def render(values: dict) -> pathlib.Path:
    DST.mkdir(parents=True, exist_ok=True)
    for src in SRC.iterdir():
        if not src.is_file():
            continue
        dest_name = src.name[:-5] if src.name.endswith(".tmpl") else src.name
        text = src.read_text()
        for key, value in values.items():
            text = text.replace(key, str(value))
        dest = DST / dest_name
        dest.write_text(text)
        dest.chmod(stat.S_IRUSR | stat.S_IWUSR)
    return DST


def main() -> None:
    values = {
        "<IT_PW>": os.environ.get("IT_PW", ""),
        "<CANVAS_DB_POOL>": os.environ.get("CANVAS_DB_POOL", "8"),
        "<CANVAS_DEFAULT_DOMAIN>": os.environ.get("CANVAS_DEFAULT_DOMAIN", "canvas.ed"),
        "<CANVAS_FILES_DEFAULT_DOMAIN>": os.environ.get("CANVAS_FILES_DEFAULT_DOMAIN", "files.ed"),
        "<CANVAS_SECRET>": os.environ.get("CANVAS_SECRET", ""),
        "<CANVAS_JWT_ENCRYPTION_KEY>": os.environ.get("CANVAS_JWT_ENCRYPTION_KEY", ""),
        "<CANVAS_ENC_SECRET>": os.environ.get("CANVAS_ENC_SECRET", ""),
        "<CANVAS_SIGN_SECRET>": os.environ.get("CANVAS_SIGN_SECRET", ""),
        "<CANVAS_RCE_DEFAULT_DOMAIN>": os.environ.get("CANVAS_RCE_DEFAULT_DOMAIN", "rce.ed"),
        "<CANVAS_MATHMAN_DEFAULT_DOMAIN>": os.environ.get("CANVAS_MATHMAN_DEFAULT_DOMAIN", "mathman.ed"),
        "<ALERT_EMAIL>": os.environ.get("ALERT_EMAIL", "alert@ed"),
    }
    dest = render(values)
    print(f"rendered Canvas runtime config to {dest}")


if __name__ == "__main__":
    main()
