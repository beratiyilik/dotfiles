#!/usr/bin/env bash
# Source-only library (see docs/INTERNALS.md). The repo-wide logging engine:
# composes the ANSI palette (core/palette.sh) and predicate guards
# (core/guards.sh), then adds a level-aware log() and the log_info/ok/warn/error
# wrappers. Sourced by bin/dotfiles and os/lib.sh — deliberately NOT by
# interactive shells, which source core/palette.sh directly for color and never
# need log()/confirm() (whose bare names would shadow the macOS `log` binary and
# other commands). Interactive-safe: never sets shell options, never calls exit.
# Idempotent via __DF_UTILS_LOADED.
[[ -n "${__DF_UTILS_LOADED:-}" ]] && return 0
readonly __DF_UTILS_LOADED=1

# $DOTFILES is derived+exported at the entry point (bin/dotfiles / .zshenv /
# .bashrc / os/lib.sh — see docs/INTERNALS.md); libraries only ever trust it.
: "${DOTFILES:?DOTFILES not set — derive it at the entry point (see docs/INTERNALS.md)}"
source "$DOTFILES/core/palette.sh"  # ANSI palette (FG_*/STYLE_*) — pure leaf
source "$DOTFILES/core/guards.sh"   # predicate guards (is_macos / has_cmd …)

# log <level> <message> — level-aware logger. Levels: DEBUG INFO OK WARN ERROR
# (SUCCESS is accepted as a synonym for OK). Respects $SILENT (suppresses all but
# ERROR) and $VERBOSE=false (suppresses all but ERROR). Both default to the
# unset-safe values, so callers that set neither get every line. WARN and ERROR
# go to stderr; ERROR always prints regardless of $SILENT.
log() {
    local level="${1:-INFO}" message="${2:-}" upper
    upper=$(printf '%s' "$level" | tr '[:lower:]' '[:upper:]')
    [[ "$upper" != ERROR && "${SILENT:-false}"  == true  ]] && return 0
    [[ "$upper" != ERROR && "${VERBOSE:-true}"   == false ]] && return 0
    case "$upper" in
        DEBUG)      printf "${FG_MAGENTA}[debug]${STYLE_RESET} %s\n" "$message" ;;
        INFO)       printf "${FG_BLUE}[info]${STYLE_RESET}  %s\n"    "$message" ;;
        OK|SUCCESS) printf "${FG_GREEN}[ok]${STYLE_RESET}    %s\n"   "$message" ;;
        WARN)       printf "${FG_YELLOW}[warn]${STYLE_RESET}  %s\n"  "$message" >&2 ;;
        ERROR)      printf "${FG_RED}[error]${STYLE_RESET} %s\n"     "$message" >&2 ;;
        *)          printf "${FG_WHITE}[%s]${STYLE_RESET} %s\n" "$upper" "$message" >&2 ;;
    esac
}

log_info()  { log INFO  "$*"; }
log_ok()    { log OK    "$*"; }
log_warn()  { log WARN  "$*"; }
log_error() { log ERROR "$*"; }

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
