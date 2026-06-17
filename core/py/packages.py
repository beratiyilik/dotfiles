#!/usr/bin/env python3
"""Diff installed Homebrew packages against the Brewfile.

CLI: packages.py [macos]. Reports formulae/casks that are installed but absent
from the Brewfile (tap / mas / vscode lines are out of scope). Linux is not
implemented yet.
"""
import subprocess
import sys
import os
from pathlib import Path

DOTFILES = Path(os.environ.get("DOTFILES", Path.home() / "dotfiles"))


def _brew_list(kind: str) -> set[str]:
    # kind: "--formula" or "--cask"
    try:
        r = subprocess.run(["brew", "list", kind],
                           capture_output=True, text=True, check=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        return set()
    return set(r.stdout.split())


def installed_brew() -> tuple[set[str], set[str]]:
    return _brew_list("--formula"), _brew_list("--cask")


def wanted_brew() -> tuple[set[str], set[str]]:
    # tap / mas / vscode lines are out of scope; brew + cask only.
    p = DOTFILES / "config" / "homebrew" / "Brewfile"
    formulae: set[str] = set()
    casks: set[str] = set()
    if not p.exists():
        return formulae, casks
    with open(p) as f:
        for line in f:
            line = line.strip()
            if line.startswith("brew "):
                formulae.add(line.split()[1].strip('"\''))
            elif line.startswith("cask "):
                casks.add(line.split()[1].strip('"\''))
    return formulae, casks


def _report(label: str, installed: set[str], wanted: set[str]) -> bool:
    missing = wanted - installed
    extra   = installed - wanted
    clean = not missing and not extra
    if missing:
        print(f"\n[missing/{label}] in Brewfile, not installed:")
        for p in sorted(missing):
            print(f"  - {p}")
    if extra:
        print(f"\n[extra/{label}] installed but not in Brewfile:")
        for p in sorted(extra):
            print(f"  + {p}")
    return clean


def diff_brew() -> None:
    inst_f, inst_c = installed_brew()
    want_f, want_c = wanted_brew()
    clean_f = _report("formula", inst_f, want_f)
    clean_c = _report("cask", inst_c, want_c)
    if clean_f and clean_c:
        print("[ok] installed packages match the Brewfile.")


if __name__ == "__main__":
    os_arg = sys.argv[1] if len(sys.argv) > 1 else "macos"
    if os_arg == "macos":
        diff_brew()
    else:
        print("linux package diff is not implemented yet.", file=sys.stderr)
