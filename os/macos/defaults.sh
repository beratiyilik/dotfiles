#!/usr/bin/env bash
# =============================================================================
# defaults.sh — macOS system preferences engine
#
# Description:
#   Applies opinionated macOS preferences declared in defaults.conf (and the
#   optional, gitignored defaults.local.conf machine overrides) via
#   `defaults write`. Each manifest row is one setting:
#
#     group  domain  key  type  value
#
#   Some changes require logging out or restarting the affected application.
#
# Usage:
#   defaults.sh [OPTIONS] [SECTIONS]
#
# Sections (filter by manifest `group`):
#   --dock          Dock layout and behaviour
#   --finder        Finder display and navigation
#   --keyboard      Key repeat, press-and-hold, text substitution
#   --screenshots   Format, location, shadow
#   --global        Miscellaneous global preferences
#   -a, --all       Apply all sections (default when no section is given)
#
# Options:
#   --sync          Capture current values that differ from defaults.conf into
#                   defaults.local.conf (instead of applying)
#   -d, --dry-run   Show what would change without applying anything
#   -f, --force     Skip confirmation prompts
#   -s, --silent    Suppress all output except errors
#   -v, --verbose   Enable verbose output (default)
#   -h, --help      Show this help and exit
#
# Dependencies:
#   - defaults, killall (macOS built-ins)
#
# Return Codes:
#   0    Success
#   64   Invalid usage (unknown option)
# =============================================================================

[[ "${BASH_SOURCE[0]}" != "$0" ]] && { printf "[ERROR] Do not source this script\n" >&2; exit 64; }

LIB_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$LIB_DIR/../lib.sh" ]] || { printf "[ERROR] lib.sh not found: %s\n" "$LIB_DIR/../lib.sh" >&2; exit 1; }
source "$LIB_DIR/../lib.sh"

# basename of this script
SCRIPT_NAME="$(basename "$0")"

# =============================================================================
# configuration
# =============================================================================

DRY_RUN=false
SILENT=false
VERBOSE=true
YES=false

# --sync captures current values instead of applying the manifest
DO_SYNC=false

DO_DOCK=false
DO_FINDER=false
DO_KEYBOARD=false
DO_SCREENSHOTS=false
DO_GLOBAL=false

# declarative manifests: committed base + optional gitignored machine overrides
DEFAULTS_CONF="$LIB_DIR/defaults.conf"
DEFAULTS_LOCAL_CONF="$LIB_DIR/defaults.local.conf"

# =============================================================================
# help
# =============================================================================

show_help() {
	cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS] [SECTIONS]

Settings are declared in:
  defaults.conf         committed base (source of truth)
  defaults.local.conf   optional, gitignored machine-specific overrides

Sections (default: all):
  --dock          Dock layout and behaviour
  --finder        Finder display and navigation
  --keyboard      Key repeat, press-and-hold, text substitution
  --screenshots   Format, location, shadow
  --global        Miscellaneous global preferences
  -a, --all       Apply all sections

Options:
  --sync          Capture current values that differ from the base manifest
                  into defaults.local.conf (does not apply anything)
  -d, --dry-run   Show what would change without applying anything
  -f, --force     Skip confirmation prompts
  -s, --silent    Suppress all output except errors
  -v, --verbose   Enable verbose output (default; overrides --silent)
  -h, --help      Show this help and exit

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --dock --finder
  ${SCRIPT_NAME} --all --force
  ${SCRIPT_NAME} --dry-run
  ${SCRIPT_NAME} --sync

EOF
}

# =============================================================================
# parse_args
# =============================================================================

parse_args() {
	local any_section=false

	while (( $# > 0 )); do
		case "$1" in
		--dock)         DO_DOCK=true;         any_section=true ;;
		--finder)       DO_FINDER=true;       any_section=true ;;
		--keyboard)     DO_KEYBOARD=true;     any_section=true ;;
		--screenshots)  DO_SCREENSHOTS=true;  any_section=true ;;
		--global)       DO_GLOBAL=true;       any_section=true ;;
		-a | --all)
			DO_DOCK=true; DO_FINDER=true; DO_KEYBOARD=true
			DO_SCREENSHOTS=true; DO_GLOBAL=true
			any_section=true
			;;
		--sync | --capture) DO_SYNC=true ;;
		-d | --dry-run) DRY_RUN=true ;;
		-f | --force)   YES=true ;;
		-s | --silent)  SILENT=true; VERBOSE=false ;;
		-v | --verbose) VERBOSE=true; SILENT=false ;;
		-h | --help)    show_help; exit $EXIT_SUCCESS ;;
		-* | --*)
			error "Unknown option: $1"
			show_help
			return $EXIT_INVALID_USAGE
			;;
		*)
			error "Unexpected argument: $1"
			return $EXIT_INVALID_USAGE
			;;
		esac
		shift
	done

	if [[ "$any_section" == false ]]; then
		DO_DOCK=true; DO_FINDER=true; DO_KEYBOARD=true
		DO_SCREENSHOTS=true; DO_GLOBAL=true
	fi
}

# =============================================================================
# helpers
# =============================================================================

# _set <domain> <key> <type> <value>   (type: bool|int|float|string)
_set() {
	run_cmd defaults write "$1" "$2" "-$3" "$4"
}

# _restart <app-name>
_restart() {
	if pgrep -xq "$1" 2>/dev/null; then
		run_cmd killall "$1" 2>/dev/null || true
		debug "Restarted: $1"
	fi
}

# _group_selected <group> — true if the group's section flag is enabled
_group_selected() {
	case "$1" in
	dock)        [[ "$DO_DOCK"        == true ]] ;;
	finder)      [[ "$DO_FINDER"      == true ]] ;;
	keyboard)    [[ "$DO_KEYBOARD"    == true ]] ;;
	screenshots) [[ "$DO_SCREENSHOTS" == true ]] ;;
	global)      [[ "$DO_GLOBAL"      == true ]] ;;
	*)           warn "Unknown group '$1' in manifest"; return 1 ;;
	esac
}

# =============================================================================
# apply
# =============================================================================

# _apply_file <manifest> — apply every selected row of a manifest file
_apply_file() {
	local file="$1"
	[[ -f "$file" ]] || return 0

	local group domain key type value
	# IFS override: lib.sh sets IFS to newline+tab, but the manifest is
	# whitespace-aligned, so split on spaces/tabs here. `value` takes the rest.
	while IFS=$' \t' read -r group domain key type value || [[ -n "${group:-}" ]]; do
		[[ -z "${group:-}" || "$group" == \#* ]] && continue
		_group_selected "$group" || continue
		# a leading ~ expands to $HOME (e.g. screenshot location)
		value="${value/#\~/$HOME}"
		_set "$domain" "$key" "$type" "$value"
	done < "$file"
}

# apply_extras — non-`defaults` operations that don't fit the manifest table
apply_extras() {
	# unhide ~/Library in Finder
	run_cmd chflags nohidden "${HOME}/Library" 2>/dev/null || true
}

apply_all() {
	info "Applying macOS defaults from manifest"
	_apply_file "$DEFAULTS_CONF"
	_apply_file "$DEFAULTS_LOCAL_CONF"   # machine overrides win (applied last)
	[[ "$DO_FINDER" == true ]] && apply_extras
	success "Defaults applied"
}

# =============================================================================
# sync — capture current values that differ from the base manifest
# =============================================================================

sync_all() {
	[[ -f "$DEFAULTS_CONF" ]] || { error "Base manifest not found: $DEFAULTS_CONF"; return $EXIT_INVALID_USAGE; }

	info "Capturing current values that differ from the base manifest"

	local tmp
	tmp="$(mktemp)"
	{
		printf "# defaults.local.conf — machine-specific macOS preference overrides\n"
		printf "# Generated by \`%s --sync\` on %s\n" "$SCRIPT_NAME" "$(date '+%Y-%m-%d %H:%M')"
		printf "# Only keys whose current value differs from defaults.conf are listed.\n"
		printf "#\n# group domain key type value\n\n"
	} > "$tmp"

	local group domain key type value current count=0
	while IFS=$' \t' read -r group domain key type value || [[ -n "${group:-}" ]]; do
		[[ -z "${group:-}" || "$group" == \#* ]] && continue
		_group_selected "$group" || continue
		value="${value/#\~/$HOME}"

		current="$(defaults read "$domain" "$key" 2>/dev/null || true)"
		[[ -z "$current" ]] && continue

		# normalize booleans: `defaults read` returns 1/0, the manifest uses true/false
		if [[ "$type" == bool ]]; then
			case "$current" in
			1) current=true ;;
			0) current=false ;;
			esac
		fi

		[[ "$current" == "$value" ]] && continue

		printf "%-12s %-26s %-36s %-7s %s\n" "$group" "$domain" "$key" "$type" "$current" >> "$tmp"
		info "captured: $domain $key = $current  (base: $value)"
		count=$((count + 1))
	done < "$DEFAULTS_CONF"

	if [[ "$count" -eq 0 ]]; then
		info "No differences from base — nothing to capture."
		rm -f "$tmp"
		return $EXIT_SUCCESS
	fi

	if [[ "$DRY_RUN" == true ]]; then
		warn "[DRY-RUN] would write $count override(s) to $DEFAULTS_LOCAL_CONF"
		rm -f "$tmp"
	else
		mv "$tmp" "$DEFAULTS_LOCAL_CONF"
		success "Wrote $count override(s) to $DEFAULTS_LOCAL_CONF"
		info "Review with: git diff --no-index /dev/null \"$DEFAULTS_LOCAL_CONF\" (gitignored)"
	fi
	return $EXIT_SUCCESS
}

# =============================================================================
# main
# =============================================================================

main() {
	parse_args "$@" || return $?

	if ! is_macos; then
		error "This script is macOS only."
		return $EXIT_INVALID_USAGE
	fi

	# --sync: capture current state and exit (never applies)
	if [[ "$DO_SYNC" == true ]]; then
		sync_all
		return $?
	fi

	if [[ "$DRY_RUN" == true ]]; then
		warn "Dry-run mode — no changes will be applied"
	else
		confirm_prompt "Apply macOS system preferences? Some changes require a logout to take full effect." \
			|| { info "Aborted."; return $EXIT_SUCCESS; }
	fi

	local start_time
	start_time=$(date +%s)

	apply_all

	if [[ "$DRY_RUN" == false ]]; then
		info "Restarting affected applications..."
		_restart Dock
		_restart Finder
		_restart SystemUIServer
	fi

	success "macOS defaults applied in $(elapsed_time "$start_time")"
	info "Log out and back in for all changes to take full effect."

	return $EXIT_SUCCESS
}

main "$@"
exit $?

## eof
