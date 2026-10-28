#!/usr/bin/env python3
"""Apply reviewed OPE source changes. Fail if the expected text is gone."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")


def replace(path: pathlib.Path, old: str, new: str) -> None:
    text = path.read_text()
    if new in text:
        print(f"already patched {path}")
        return
    if old not in text:
        raise SystemExit(f"expected text not found in {path}: {old!r}")
    path.write_text(text.replace(old, new, 1))
    print(f"patched {path}")


def main() -> int:
    versioned = ROOT / "config" / "initializers" / "simply_versioned.rb"
    if versioned.is_file():
        replace(versioned, "5_000_000", "1_000_000_000_000_000")
    switchman = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else None
    if switchman:
        replace(switchman / "lib" / "switchman" / "shard.rb", "10_000_000_000_000", "1_000_000_000_000_000")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
