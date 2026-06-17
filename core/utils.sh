#!/usr/bin/env bash
# Source-only library (see docs/INTERNALS.md). Idempotent: guarded
# against double-sourcing via __DF_UTILS_LOADED.
[[ -n "${__DF_UTILS_LOADED:-}" ]] && return 0
readonly __DF_UTILS_LOADED=1

# Shared predicate guards (is_macos / is_linux / has_cmd …); self-guarded, dependency-free.
source "$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)/guards.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

log_info()  { echo -e "${BLUE}[info]${RESET}  $*"; }
log_ok()    { echo -e "${GREEN}[ok]${RESET}    $*"; }
log_warn()  { echo -e "${YELLOW}[warn]${RESET}  $*"; }
log_error() { echo -e "${RED}[error]${RESET} $*" >&2; }

confirm() {
    local prompt="${1:-Continue?}"
    read -r -p "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

# clone_if_missing <dest> <repo> — idempotent, fault-tolerant shallow clone.
# Skips when <dest> already exists; warns (never aborts) when git is absent or
# the clone fails, so callers under `set -e` (e.g. hooks) stay safe.
clone_if_missing() {
    local dest="$1" repo="$2"
    [[ -d "$dest" ]] && return 0
    has_cmd git || { log_warn "git missing — cannot clone ${dest##*/}."; return 0; }
    log_info "Cloning ${dest##*/}…"
    git clone --depth=1 "$repo" "$dest" || log_warn "Failed to clone ${dest##*/} — skipping."
    return 0
}
