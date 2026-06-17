#!/usr/bin/env bash
# =============================================================================
# update.sh — system-wide package and software update script (Linux)
#
# Description:
#   STATUS: placeholder. Not implemented yet — this stub exists so that
#   `dotfiles upgrade` dispatches cleanly on Linux. Mirror the behavior of the
#   macOS counterpart os/macos/update.sh when filling it in.
#
#   Planned:
#     1. apt update && apt full-upgrade   (sudo, apt-get fallback)
#     2. snap / flatpak updates           (if present)
#     3. Node.js global packages          (pnpm or npm, nvm-aware)
#     4. Ruby gems
#     5. Python pip packages
#
# Usage:
#   update.sh [OPTIONS]
#
# Options (planned):
#   -y, --yes       Auto-confirm all prompts
#   -d, --dry-run   Show what would run without executing anything
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

info "$SCRIPT_NAME: Linux 'upgrade' is not implemented yet (placeholder)."
info "Planned: apt full-upgrade + snap/flatpak + npm/pip/gem. See os/macos/update.sh."
exit "${EXIT_SUCCESS:-0}"
