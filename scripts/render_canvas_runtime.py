#!/usr/bin/env python3
"""Render Canvas runtime YAML into a gitignored host directory."""

import os
import pathlib
import shutil
import subprocess
import sys

from template_utils import process_conditional_blocks

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "ope-canvas" / "runtime"
DST = ROOT / "ope-canvas" / "runtime-rendered"

# The Canvas containers run as uid/gid 9999 and read these files through a
# read-only bind mount. The files hold the database password and Canvas
# secrets, so they must not be world-readable.
CANVAS_UID = 9999
CANVAS_GID = 9999
DIR_MODE = 0o750
FILE_MODE = 0o640


def _run_quiet(cmd):
    return subprocess.call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0


def _grant_canvas_access(paths):
    """Give the Canvas user read access to *paths*. Returns True on success."""
    try:
        for path in paths:
            os.chown(str(path), -1, CANVAS_GID)
        return True
    except OSError:
        pass

    if os.geteuid() != 0 and shutil.which("sudo"):
        if _run_quiet(["sudo", "-n", "chgrp", str(CANVAS_GID)] + [str(p) for p in paths]):
            return True

    # The file owner may add an ACL entry without root.
    if shutil.which("setfacl"):
        for path in paths:
            perms = "rx" if path.is_dir() else "r"
            if not _run_quiet(["setfacl", "-m", "u:{}:{}".format(CANVAS_UID, perms), str(path)]):
                return False
        return True

    return False


def _runtime_access_error():
    return (
        "ERROR: could not give the Canvas user (uid/gid {uid}) read access to {dst}.\n"
        "       Run ./scripts/rebuild.sh as root (sudo), or install the 'acl'\n"
        "       package so setfacl is available, then run it again.".format(
            uid=CANVAS_UID, dst=DST
        )
    )


def render(values: dict) -> pathlib.Path:
    try:
        DST.mkdir(parents=True, exist_ok=True)
        os.chmod(str(DST), DIR_MODE)
        written = []
        for src in sorted(SRC.iterdir()):
            if not src.is_file():
                continue
            dest_name = src.name[:-5] if src.name.endswith(".tmpl") else src.name
            text = process_conditional_blocks(src.read_text(), values)
            for key, value in values.items():
                text = text.replace(key, str(value))
            dest = DST / dest_name
            fd = os.open(str(dest), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, FILE_MODE)
            with os.fdopen(fd, "w") as f:
                f.write(text)
            os.chmod(str(dest), FILE_MODE)
            written.append(dest)
    except PermissionError:
        # An earlier sudo ./up.sh can leave runtime-rendered owned by root.
        # os.chmod / os.open then raise before _grant_canvas_access can explain it.
        sys.exit(_runtime_access_error())

    if not _grant_canvas_access([DST] + written):
        sys.exit(_runtime_access_error())
    return DST


def main() -> None:
    values = {
        "<IT_PW>": os.environ.get("IT_PW", ""),
        "<CANVAS_DB_POOL>": os.environ.get("CANVAS_DB_POOL", "8"),
        "<CANVAS_DEFAULT_DOMAIN>": os.environ.get("CANVAS_DEFAULT_DOMAIN", "canvas.ed"),
        "<CANVAS_SECRET>": os.environ.get("CANVAS_SECRET", ""),
        "<CANVAS_JWT_ENCRYPTION_KEY>": os.environ.get("CANVAS_JWT_ENCRYPTION_KEY", ""),
        "<CANVAS_JWT_ENCRYPTION_KEY_PREVIOUS>": os.environ.get(
            "CANVAS_JWT_ENCRYPTION_KEY_PREVIOUS", ""
        ),
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
