#!/usr/bin/env python3
"""Render a `{{VAR}}` template to a target, substituting vars/*.env values.

CLI: template.py <src.tmpl> <target>. Vars load from common.env then local.env
(same KEY=value parsing as exports.sh). Rendered output is written 0600 (it may
carry secrets from local.env); a ~/.ssh target dir is forced to 0700.
"""
import os
import re
import sys
from pathlib import Path

DOTFILES = Path(os.environ.get("DOTFILES", Path.home() / "dotfiles"))


def load_vars() -> dict[str, str]:
    # Format: KEY=value (no export, no shell expansion). Same as exports.sh.
    env: dict[str, str] = {}
    for fname in ("common.env", "local.env"):
        p = DOTFILES / "vars" / fname
        if not p.exists():
            continue
        with open(p) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def render(src: Path, target: Path, env: dict[str, str]) -> None:
    text = src.read_text()

    def replacer(m):
        key = m.group(1).strip()
        if key not in env:
            print(f"[template] warning: {key} is not defined", file=sys.stderr)
            return m.group(0)
        return env[key]

    rendered = re.sub(r"\{\{(.+?)\}\}", replacer, text)

    target.parent.mkdir(parents=True, exist_ok=True)
    # ssh ignores the config file unless the ~/.ssh directory is 0700.
    if target.parent.name == ".ssh":
        target.parent.chmod(0o700)

    target.write_text(rendered)
    # Rendered files may contain secrets from local.env → 0600.
    target.chmod(0o600)
    print(f"[template] rendered: {src} → {target}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: template.py <src.tmpl> <target>", file=sys.stderr)
        sys.exit(1)
    env = load_vars()
    render(Path(sys.argv[1]), Path(sys.argv[2]), env)
