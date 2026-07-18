#!/usr/bin/env bash
# =============================================================================
# lib.sh — shared utilities for dotfiles OS maintenance scripts (macOS + Linux)
#
# Lives at os/lib.sh and is sourced by the per-OS scripts one level up, e.g.
# from os/macos/<script>.sh:
#   LIB_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$LIB_DIR/../lib.sh"
#
# Provides:
#   - strict mode (errexit, nounset, pipefail, IFS)
#   - exit codes
#   - ANSI color / style constants
#   - logging: log(), debug(), info(), success(), warn(), error()
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
# Guards against double-sourcing via LIB_LOADED.
# =============================================================================

# guard: do not load twice
[[ -n "${LIB_LOADED:-}" ]] && return 0
readonly LIB_LOADED=1

# =============================================================================
# strict mode
# =============================================================================

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# Entry-point boundary: os/*.sh are execute-only and, when run directly, inherit
# no $DOTFILES. Derive+export it once here (honoring an inherited value from a
# bin/dotfiles subprocess) so every core library below can simply trust it. This
# is the os counterpart of the derivation in bin/dotfiles / .zshenv / .bashrc.
# Execute-only scripts run in bash, where BASH_SOURCE is reliable.
: "${DOTFILES:=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export DOTFILES

# Logging engine, ANSI palette, and predicate guards come from core/utils.sh
# (the repo-wide standard).
source "$DOTFILES/core/utils.sh"

# =============================================================================
# exit codes
# =============================================================================

: "${EXIT_SUCCESS:=0}";        readonly EXIT_SUCCESS
: "${EXIT_AUTH_FAILED:=20}";   readonly EXIT_AUTH_FAILED
: "${EXIT_INVALID_USAGE:=64}"; readonly EXIT_INVALID_USAGE
: "${EXIT_CMD_NOT_FOUND:=127}"; readonly EXIT_CMD_NOT_FOUND

# =============================================================================
# logging
# =============================================================================

# The ANSI palette and the level-aware log() live in core/utils.sh (sourced
# above). These short-name wrappers are the log API the execute-only os/*.sh
# scripts use; success maps to the OK level. All scale with $SILENT / $VERBOSE.
debug()   { log DEBUG "$*"; }
info()    { log INFO  "$*"; }
success() { log OK    "$*"; }
warn()    { log WARN  "$*"; }
error()   { log ERROR "$*"; }

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
	read -r reply
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
