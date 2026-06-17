#!/usr/bin/env bash
# =============================================================================
# snapshot.sh — environment inventory snapshot (Linux)
#
# Description:
#   STATUS: placeholder. Not implemented yet — this stub exists so that
#   `dotfiles snapshot` dispatches cleanly on Linux. Mirror the behavior of the
#   macOS counterpart os/macos/snapshot.sh when filling it in (read-only dump to
#   $DOTFILES/backups/snapshot_<stamp>/, one .txt per section).
#
#   Planned sections:
#     - system      uname -a, lsb_release, /etc/os-release, CPU/mem
#     - packages    dpkg -l / apt list --installed, snap list, flatpak list
#     - node/python/ruby   language runtime + global package inventories
#     - env         shell environment and dotfiles inventory
#     - crontab     crontab -l
#
# Usage:
#   snapshot.sh [OPTIONS]
#
# Options (planned):
#   -o, --output <dir>   Base output directory (default: $DOTFILES/backups);
#                        the run lands in <dir>/snapshot_<stamp>/
#   -d, --dry-run        Show what would run without writing any files
#   -h, --help           Show this help and exit
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

info "$SCRIPT_NAME: Linux 'snapshot' is not implemented yet (placeholder)."
info "Planned: dpkg/snap/flatpak + uname + runtime inventories. See os/macos/snapshot.sh."
exit "${EXIT_SUCCESS:-0}"
