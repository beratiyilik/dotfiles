#!/usr/bin/env bash
# =============================================================================
# cleanup.sh — system cleanup script (Linux)
#
# Description:
#   STATUS: placeholder. Not implemented yet — this stub exists so that
#   `dotfiles cleanup` dispatches cleanly on Linux. Mirror the behavior of the
#   macOS counterpart os/macos/cleanup.sh when filling it in.
#
#   Planned targets:
#     - apt autoremove / apt clean (orphaned packages, cached .deb archives)
#     - ~/.cache and thumbnail cache
#     - journald logs (journalctl --vacuum-*)
#     - Vim swap / Python __pycache__ under CWD (do not run from ~)
#     - /tmp, $TMPDIR contents
#
# Usage:
#   cleanup.sh [OPTIONS] [TARGETS]
#
# Options (planned):
#   -y, --yes       Auto-confirm all prompts
#   -d, --dry-run   Show what would be removed without removing anything
#   -h, --help      Show this help and exit
#
# Return Codes:
#   0    Success (placeholder always exits 0)
# =============================================================================

# must be executed directly, not sourced
[[ "${BASH_SOURCE[0]}" != "$0" ]] && { printf "[ERROR] Do not source this script\n" >&2; exit 64; }

# load shared utilities (lives one level up: os/lib.sh, shared across OSes)
LIB_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/../lib.sh"

SCRIPT_NAME="$(basename "$0")"

info "$SCRIPT_NAME: Linux 'cleanup' is not implemented yet (placeholder)."
info "Planned: apt autoremove/clean + ~/.cache + journald logs + tmp. See os/macos/cleanup.sh."
exit "${EXIT_SUCCESS:-0}"
