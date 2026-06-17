#!/usr/bin/env zsh
# =============================================================================
# lib.zsh — shared utilities for dotfiles scripts
#
# Usage:
#   source "$DOTFILES/system/macos/lib.zsh"
#
# Provides:
#   - strict mode (errexit, nounset, pipefail, IFS)
#   - exit codes
#   - ANSI color / style constants
#   - logging: log(), debug(), info(), success(), warn(), error(), print()
#   - run_cmd()        — dry-run aware command executor
#   - confirm_prompt() — interactive y/N prompt, respects $YES
#   - sudo_keepalive_start() / sudo_keepalive_stop()
#   - elapsed_time()   — prints duration from a start timestamp
#
# Expected globals (set by the sourcing script before calling any function):
#   DRY_RUN  — "true" | "false"
#   SILENT   — "true" | "false"
#   VERBOSE  — "true" | "false"
#   YES      — "true" | "false"
#
# Guards against double-sourcing via _LIB_LOADED.
# =============================================================================

# guard: do not load twice
[[ -n "${_LIB_LOADED:-}" ]] && return 0
readonly _LIB_LOADED=1

# =============================================================================
# strict mode
# =============================================================================

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# =============================================================================
# exit codes
# =============================================================================

: "${EXIT_SUCCESS:=0}";        readonly EXIT_SUCCESS
: "${EXIT_AUTH_FAILED:=20}";   readonly EXIT_AUTH_FAILED
: "${EXIT_INVALID_USAGE:=64}"; readonly EXIT_INVALID_USAGE
: "${EXIT_CMD_NOT_FOUND:=127}"; readonly EXIT_CMD_NOT_FOUND

# =============================================================================
# ANSI style constants
# =============================================================================

# attributes
: "${STYLE_RESET:=\033[0m}";     readonly STYLE_RESET
: "${STYLE_BOLD:=\033[1m}";      readonly STYLE_BOLD
: "${STYLE_BLINK_ON:=\033[5m}";  readonly STYLE_BLINK_ON
: "${STYLE_BLINK_OFF:=\033[25m}"; readonly STYLE_BLINK_OFF

# foreground colors
: "${FG_BLUE:=\033[38;5;31m}";    readonly FG_BLUE
: "${FG_CYAN:=\033[38;5;66m}";    readonly FG_CYAN
: "${FG_GRAY:=\033[38;5;244m}";   readonly FG_GRAY
: "${FG_GREEN:=\033[38;5;76m}";   readonly FG_GREEN
: "${FG_MAGENTA:=\033[0;35m}";    readonly FG_MAGENTA
: "${FG_RED:=\033[38;5;196m}";    readonly FG_RED
: "${FG_WHITE:=\033[0;37m}";      readonly FG_WHITE
: "${FG_YELLOW:=\033[38;5;220m}"; readonly FG_YELLOW

# =============================================================================
# logging
# =============================================================================

# log <level> <message>
# Levels: DEBUG INFO SUCCESS WARN ERROR
# Respects $SILENT and $VERBOSE globals.
# WARN and ERROR always go to stderr.
# ERROR always prints regardless of SILENT.
log() {
	local level="${1:-INFO}"
	local message="${2:-}"
	local upper_level
	upper_level=$(echo "$level" | tr '[:lower:]' '[:upper:]')

	# ERROR always prints; everything else suppressed when SILENT=true
	if [[ "$upper_level" != "ERROR" && "${SILENT:-false}" == true ]]; then return; fi
	# non-ERROR suppressed when VERBOSE=false
	if [[ "$upper_level" != "ERROR" && "${VERBOSE:-true}" == false ]]; then return; fi

	case "$upper_level" in
	DEBUG)   printf "${FG_MAGENTA}[DEBUG]${STYLE_RESET} %s\n"           "$message" ;;
	INFO)    printf "${FG_BLUE}[INFO]${STYLE_RESET} %s\n"               "$message" ;;
	SUCCESS) printf "${FG_GREEN}[SUCCESS]${STYLE_RESET} %s\n"           "$message" ;;
	WARN)    printf "${FG_YELLOW}[WARN]${STYLE_RESET} %s\n"             "$message" >&2 ;;
	ERROR)   printf "${FG_RED}[ERROR]${STYLE_RESET} %s\n"               "$message" >&2 ;;
	*)       printf "${FG_WHITE}[%s]${STYLE_RESET} %s\n" "$upper_level" "$message" >&2 ;;
	esac
}

debug()   { log "DEBUG"   "$1"; }
info()    { log "INFO"    "$1"; }
success() { log "SUCCESS" "$1"; }
warn()    { log "WARN"    "$1"; }
error()   { log "ERROR"   "$1"; }
print()   { printf "%s\n" "$1"; }

# =============================================================================
# run_cmd
# =============================================================================

# run_cmd <cmd> [args...]
# Executes the command normally, or prints it prefixed with [DRY-RUN] when
# DRY_RUN=true. Never executes anything in dry-run mode.
run_cmd() {
	if [[ "${DRY_RUN:-false}" == true ]]; then
		info "[DRY-RUN] $*"
	else
		"$@"
	fi
}

# =============================================================================
# confirm_prompt
# =============================================================================

# confirm_prompt <prompt>
# Prints prompt and waits for y/Y. Returns 0 on confirmation, 1 otherwise.
# Returns 0 immediately when YES=true (non-interactive mode).
confirm_prompt() {
	local prompt="${1:-Continue?}"
	if [[ "${YES:-false}" == true ]]; then
		return 0
	fi
	printf "${FG_YELLOW}%s${STYLE_RESET} (y/N) " "$prompt"
	local reply
	read -r "reply"
	[[ "$reply" =~ ^[yY] ]]
}

# =============================================================================
# sudo keep-alive
# =============================================================================

# Caches sudo credentials once and refreshes them every 60 s in a background
# process so long-running scripts do not hit a sudo timeout mid-run.
#
# Usage:
#   trap sudo_keepalive_stop EXIT INT TERM
#   sudo_keepalive_start || warn "..."
#   ... privileged work ...
#   sudo_keepalive_stop   # also called automatically via trap

SUDO_KEEPALIVE_PID=""

# sudo_keepalive_start
# Prompts for sudo password (once), then spawns a background refresh loop.
# Skipped entirely in dry-run mode.
# Returns EXIT_AUTH_FAILED if sudo -v fails.
sudo_keepalive_start() {
	if [[ "${DRY_RUN:-false}" == true ]]; then
		debug "[DRY-RUN] sudo_keepalive_start skipped"
		return 0
	fi
	sudo -v || return $EXIT_AUTH_FAILED
	(while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done) &
	SUDO_KEEPALIVE_PID=$!
	debug "sudo keep-alive started (PID=$SUDO_KEEPALIVE_PID)"
}

# sudo_keepalive_stop
# Terminates the background refresh loop. Safe to call even if not started.
sudo_keepalive_stop() {
	if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
		kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
		wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
		debug "sudo keep-alive stopped (PID=$SUDO_KEEPALIVE_PID)"
		SUDO_KEEPALIVE_PID=""
	fi
}

# =============================================================================
# elapsed_time
# =============================================================================

# elapsed_time <start_epoch_seconds>
# Prints "Xm Ys" computed from now minus the given start timestamp.
elapsed_time() {
	local start="${1:?elapsed_time requires a start timestamp}"
	local end elapsed minutes seconds
	end=$(date +%s)
	elapsed=$(( end - start ))
	minutes=$(( elapsed / 60 ))
	seconds=$(( elapsed % 60 ))
	printf "%dm %ds" "$minutes" "$seconds"
}

## eof