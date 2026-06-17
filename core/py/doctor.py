#!/usr/bin/env python3
"""Full environment + symlink + tooling health check.

This is the rich implementation, run by `dotfiles doctor` whenever python3 is
available; bin/dotfiles falls back to the more minimal pure-bash core/doctor.sh
when it is not. It mirrors that script's pass/warn/fail contract and its
non-zero-on-fail exit code, and absorbs the per-target link inspection that used
to be a separate `dotfiles status` command (it consumes manifest.parse the same
way status.py did).
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

from manifest import parse

RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
RESET = "\033[0m"

DOTFILES = Path(os.environ.get("DOTFILES", Path.home() / "dotfiles"))

_counts = {"ok": 0, "warn": 0, "fail": 0}


def _pass(msg: str) -> None:
    _counts["ok"] += 1
    print(f"{GREEN}[pass]{RESET}  {msg}")


def _warn(msg: str) -> None:
    _counts["warn"] += 1
    print(f"{YELLOW}[warn]{RESET}  {msg}")


def _fail(msg: str) -> None:
    _counts["fail"] += 1
    print(f"{RED}[fail]{RESET}  {msg}")


def detect_os() -> str:
    return {"Darwin": "macos", "Linux": "linux"}.get(os.uname().sysname, "unknown")


def detect_shell() -> str:
    return Path(os.environ.get("SHELL", "sh")).name


def file_mode(p: Path) -> str:
    # Last three octal digits of the permission bits (e.g. "600"), matching the
    # bash file_mode() helper's `stat` output.
    return oct(p.stat().st_mode & 0o777)[2:]


def _git(args: list[str]) -> subprocess.CompletedProcess | None:
    try:
        return subprocess.run(
            ["git", "-C", str(DOTFILES), *args],
            capture_output=True, text=True,
        )
    except FileNotFoundError:
        return None


def check_env() -> None:
    if not os.environ.get("DOTFILES"):
        _fail("DOTFILES is not set")
    elif not DOTFILES.is_dir():
        _fail(f"DOTFILES directory missing: {DOTFILES}")
    else:
        _pass(f"DOTFILES: {DOTFILES}")

    if str(DOTFILES / "bin") in os.environ.get("PATH", "").split(os.pathsep):
        _pass("$DOTFILES/bin is in PATH")
    else:
        _warn("$DOTFILES/bin not in PATH (dotfiles/dotf may not be callable)")

    # Does the dotfiles on PATH point to a different repo? (drift)
    on_path = shutil.which("dotfiles")
    if on_path:
        resolved = Path(on_path).resolve().parents[1]
        if resolved != DOTFILES.resolve():
            _warn(f"dotfiles on PATH points to a different repo: {resolved}")


def check_tools() -> None:
    if shutil.which("git"):
        rev_parse = _git(["rev-parse", "--git-dir"])
        if rev_parse is not None and rev_parse.returncode == 0:
            status = _git(["status", "--porcelain"])
            if status and status.stdout.strip():
                _warn("Repo has uncommitted changes")
            else:
                _pass("git repo is clean")
            counts = _git(["rev-list", "--count", "--left-right", "@{u}...HEAD"])
            if counts is not None and counts.returncode == 0:
                parts = counts.stdout.split()
                if len(parts) == 2:
                    behind, ahead = (int(parts[0]), int(parts[1]))
                    if behind > 0:
                        _warn(f"{behind} commit(s) behind upstream (dotfiles update)")
                    if ahead > 0:
                        _warn(f"{ahead} commit(s) ahead of upstream (not pushed)")
        else:
            _fail(f"{DOTFILES} is not a git repo")
    else:
        _warn("git missing (update won't work)")

    if shutil.which("python3"):
        _pass("python3 found")
    else:
        _warn("python3 missing (template / os --diff disabled)")

    osname = detect_os()
    if osname == "macos":
        if shutil.which("brew"):
            _pass("Homebrew found")
        else:
            _warn("brew missing (os setup won't work)")
        if not (DOTFILES / "config" / "homebrew" / "Brewfile").is_file():
            _warn("Brewfile missing")
    elif osname == "linux":
        if not (shutil.which("apt") or shutil.which("apt-get")):
            _warn("apt not found")


def check_symlinks() -> None:
    manifest = DOTFILES / ".symlinks"
    if not manifest.is_file():
        _fail(f"manifest missing: {manifest}")
        return

    for e in parse(manifest):
        if not e.src.exists():
            _fail(f"source missing: {e.src.relative_to(DOTFILES)}")
            continue

        if e.is_template:
            if not e.target.exists():
                _warn(f"template not rendered: {e.target}")
                continue
            mode = file_mode(e.target)
            if mode != "600":
                _warn(f"template mode is not 0600 ({mode}): {e.target}")
            if e.target.parent.name == ".ssh":
                dirmode = file_mode(e.target.parent)
                if dirmode != "700":
                    _warn(f"~/.ssh mode is not 0700 ({dirmode})")
            _pass(f"template: {e.target}")
            continue

        if e.target.is_symlink():
            if e.target.resolve() == e.src.resolve():
                _pass(f"link: {e.target}")
            else:
                _fail(f"wrong target: {e.target} → {os.readlink(e.target)}")
        elif e.target.exists():
            _warn(f"file exists but is not a link: {e.target}")
        else:
            _fail(f"link missing: {e.target}")


def check_misc() -> None:
    if not os.access(DOTFILES / "bin" / "dotfiles", os.X_OK):
        _warn("bin/dotfiles is not executable")
    if not os.access(DOTFILES / "bin" / "dotf", os.X_OK):
        _warn("bin/dotf is not executable")
    if not (DOTFILES / "vars" / "local.env").is_file():
        _warn("vars/local.env missing (template variables may be incomplete)")


def run_doctor() -> int:
    print(f"{BLUE}[info]{RESET}  dotfiles doctor — "
          f"OS: {detect_os()} | Shell: {detect_shell()}")
    print()
    check_env()
    check_tools()
    check_symlinks()
    check_misc()
    print()
    print(f"{GREEN}{_counts['ok']} ok{RESET}, "
          f"{YELLOW}{_counts['warn']} warn{RESET}, "
          f"{RED}{_counts['fail']} fail{RESET}")
    return 1 if _counts["fail"] > 0 else 0


if __name__ == "__main__":
    sys.exit(run_doctor())
