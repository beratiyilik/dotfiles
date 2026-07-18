#!/usr/bin/env bash
# Source-only library of pure predicates — the repo-wide standard for OS / arch
# and command-existence guards (is_macos / is_linux / is_arm64 / has_cmd …).
# No logging, no side effects. Sourced by core/utils.sh; requires $DOTFILES
# (set at the entry point — see docs/INTERNALS.md) to locate detect.sh.
# Idempotent: guarded against double-sourcing via __DF_GUARDS_LOADED.
[[ -n "${__DF_GUARDS_LOADED:-}" ]] && return 0
readonly __DF_GUARDS_LOADED=1

# Canonical OS mapping lives in detect.sh (Darwin→macos, Linux→linux).
: "${DOTFILES:?DOTFILES not set — derive it at the entry point (see docs/INTERNALS.md)}"
source "$DOTFILES/core/detect.sh"

# OS / arch predicates — quiet, return-code only (use in `if`, `&&`, `! ...`).
is_macos() { [[ "$(detect_os)" == macos ]]; }
is_linux() { [[ "$(detect_os)" == linux ]]; }
is_arm64() { [[ "$(uname -m)" == arm64 ]]; }

# Which interpreter is executing this source — set by the shell itself,
# independent of $SHELL (login-shell config). Parallels is_macos/is_linux.
is_bash() { [[ "$(detect_shell)" == bash ]]; }
is_zsh()  { [[ "$(detect_shell)" == zsh ]]; }

# has_cmd <name> — true when <name> resolves to an executable on $PATH.
has_cmd() { command -v "$1" >/dev/null 2>&1; }
