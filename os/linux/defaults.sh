#!/usr/bin/env bash
# =============================================================================
# defaults.sh — system preferences engine (Linux)
#
# Description:
#   STATUS: placeholder. Not implemented yet — this stub exists so that
#   `dotfiles defaults` dispatches cleanly on Linux. The macOS counterpart
#   os/macos/defaults.sh applies `defaults write` settings from defaults.conf;
#   the Linux analog would apply desktop/system settings via gsettings / dconf.
#
#   Planned:
#     - read a declarative manifest (group / schema / key / value)
#     - apply via `gsettings set` (GNOME) and/or `dconf write`
#     - --sync to capture current values that differ from the committed base
#
# Usage:
#   defaults.sh [OPTIONS] [SECTIONS]
#
# Options (planned):
#   --sync          Capture current values into a machine-local override file
#   -d, --dry-run   Show what would change without applying anything
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

info "$SCRIPT_NAME: Linux 'defaults' is not implemented yet (placeholder)."
info "Planned: apply desktop/system settings via gsettings / dconf. See os/macos/defaults.sh."
exit "${EXIT_SUCCESS:-0}"
