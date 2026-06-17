#!/usr/bin/env python3
"""Parse the `.symlinks` manifest into typed SymlinkEntry rows.

Shared by core/py/doctor.py and the symlink tooling so the manifest is read one
way only (src, target, is_template); leading `~` expansion mirrors the bash
${target/#\\~/$HOME} behavior.
"""
from __future__ import annotations
import os
import sys
from dataclasses import dataclass
from pathlib import Path

DOTFILES = Path(os.environ.get("DOTFILES", Path.home() / "dotfiles"))


@dataclass
class SymlinkEntry:
    src: Path
    target: Path
    is_template: bool


def _expand_target(raw: str) -> Path:
    # Same as bash ${target/#\~/$HOME}: only a leading ~ is expanded.
    if raw == "~":
        return Path.home()
    if raw.startswith("~/"):
        return Path.home() / raw[2:]
    return Path(raw)


def parse(manifest_path: Path | None = None) -> list[SymlinkEntry]:
    manifest_path = manifest_path or DOTFILES / ".symlinks"
    entries: list[SymlinkEntry] = []

    with open(manifest_path) as f:
        for lineno, raw in enumerate(f, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue

            parts = line.split()
            if len(parts) < 3 or parts[1] != "→":
                print(f"[manifest] line {lineno} invalid: {line!r}",
                      file=sys.stderr)
                continue

            src     = DOTFILES / parts[0]
            target  = _expand_target(parts[2])
            is_tmpl = len(parts) > 3 and parts[3] == "[template]"

            if not src.exists():
                print(f"[manifest] source missing (line {lineno}): {src}",
                      file=sys.stderr)

            entries.append(SymlinkEntry(src=src, target=target,
                                        is_template=is_tmpl))
    return entries


if __name__ == "__main__":
    for e in parse():
        flag = " [template]" if e.is_template else ""
        print(f"{e.src} → {e.target}{flag}")
