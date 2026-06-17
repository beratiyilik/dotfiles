#!/usr/bin/env zsh
# =============================================================================
# defaults.zsh — macOS system preferences
#
# Usage:
#   defaults.zsh [OPTIONS] [SECTIONS]
#
# Applies opinionated macOS system preferences via `defaults write`.
# Some changes require logging out or restarting the affected application.
#
# Sections:
#   --dock          Dock layout and behaviour
#   --finder        Finder display and navigation
#   --keyboard      Key repeat, press-and-hold, text substitution
#   --screenshots   Format, location, shadow
#   --global        Miscellaneous global preferences
#   -a, --all       Apply all sections (default when no section is given)
#
# Options:
#   -d, --dry-run   Show what would change without applying anything
#   -f, --force     Skip confirmation prompts
#   -s, --silent    Suppress all output except errors
#   -v, --verbose   Enable verbose output (default)
#   -h, --help      Show this help and exit
# =============================================================================

[[ "${(%):-%x}" != "$0" ]] && { printf "[ERROR] Do not source this script\n" >&2; exit 64; }

[[ -f "${0:A:h}/_lib.zsh" ]] || { printf "[ERROR] lib.zsh not found: %s\n" "${0:A:h}/_lib.zsh" >&2; exit 1; }
source "${0:A:h}/_lib.zsh"

# =============================================================================
# configuration
# =============================================================================

DRY_RUN=false
SILENT=false
VERBOSE=true
YES=false

DO_DOCK=false
DO_FINDER=false
DO_KEYBOARD=false
DO_SCREENSHOTS=false
DO_GLOBAL=false

# =============================================================================
# help
# =============================================================================

show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS] [SECTIONS]

Sections (default: all):
  --dock          Dock layout and behaviour
  --finder        Finder display and navigation
  --keyboard      Key repeat, press-and-hold, text substitution
  --screenshots   Format, location, shadow
  --global        Miscellaneous global preferences
  -a, --all       Apply all sections

Options:
  -d, --dry-run   Show what would change without applying anything
  -f, --force     Skip confirmation prompts
  -s, --silent    Suppress all output except errors
  -v, --verbose   Enable verbose output (default; overrides --silent)
  -h, --help      Show this help and exit

Examples:
  $(basename "$0")
  $(basename "$0") --dock --finder
  $(basename "$0") --all --force
  $(basename "$0") --dry-run

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

# _set <domain> <key> <type-flag> <value>
_set() {
	run_cmd defaults write "$1" "$2" "$3" "$4"
}

# _restart <app-name>
_restart() {
	if pgrep -xq "$1" 2>/dev/null; then
		run_cmd killall "$1" 2>/dev/null || true
		debug "Restarted: $1"
	fi
}

# =============================================================================
# sections
# =============================================================================

apply_dock() {
	info "Applying: Dock"

	# auto-hide — show only when cursor reaches the edge
	_set com.apple.dock autohide                    -bool  true
	_set com.apple.dock autohide-delay              -float 0
	_set com.apple.dock autohide-time-modifier      -float 0.4

	# icon size (pixels)
	_set com.apple.dock tilesize                    -int   48

	# minimize window into its app icon instead of the Dock shelf
	_set com.apple.dock minimize-to-application     -bool  true

	# hide the "Recent Applications" section
	_set com.apple.dock show-recents                -bool  false

	# do not rearrange Spaces based on recent use
	_set com.apple.dock mru-spaces                  -bool  false

	# use scale effect (faster than genie)
	_set com.apple.dock mineffect                   -string scale

	success "Dock: done"
}

apply_finder() {
	info "Applying: Finder"

	# show status bar and path bar
	_set com.apple.finder ShowStatusBar             -bool  true
	_set com.apple.finder ShowPathbar               -bool  true

	# show all file extensions
	_set NSGlobalDomain  AppleShowAllExtensions     -bool  true

	# show hidden files
	_set com.apple.finder AppleShowAllFiles         -bool  true

	# default view: list (Nlsv = list, icnv = icon, clmv = column, glyv = gallery)
	_set com.apple.finder FXPreferredViewStyle      -string Nlsv

	# sort folders before files in list/column views
	_set com.apple.finder _FXSortFoldersFirst       -bool  true

	# search the current folder by default (SCcf), not This Mac (SCev)
	_set com.apple.finder FXDefaultSearchScope      -string SCcf

	# disable the warning when changing a file extension
	_set com.apple.finder FXEnableExtensionChangeWarning -bool false

	# disable the warning when emptying the Trash
	_set com.apple.finder WarnOnEmptyTrash          -bool  false

	# do not create .DS_Store files on network or USB volumes
	_set com.apple.desktopservices DSDontWriteNetworkStores -bool true
	_set com.apple.desktopservices DSDontWriteUSBStores     -bool true

	# unhide ~/Library in Finder
	run_cmd chflags nohidden "${HOME}/Library" 2>/dev/null || true

	success "Finder: done"
}

apply_keyboard() {
	info "Applying: Keyboard"

	# InitialKeyRepeat: delay before key starts repeating
	# default: 68 (~1 s) — 15 ≈ 225 ms
	_set NSGlobalDomain InitialKeyRepeat            -int   15

	# KeyRepeat: interval between repeated keys
	# default: 6 (~83 ms) — 2 ≈ 30 ms (comfortable for coding)
	_set NSGlobalDomain KeyRepeat                   -int   2

	# disable press-and-hold accent popup → enables key repeat for all keys
	_set NSGlobalDomain ApplePressAndHoldEnabled    -bool  false

	# disable automatic text substitutions
	_set NSGlobalDomain NSAutomaticCapitalizationEnabled     -bool false
	_set NSGlobalDomain NSAutomaticDashSubstitutionEnabled   -bool false
	_set NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled  -bool false
	_set NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
	_set NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

	success "Keyboard: done"
}

apply_screenshots() {
	info "Applying: Screenshots"

	# save location
	_set com.apple.screencapture location           -string "${HOME}/Desktop"

	# file format
	_set com.apple.screencapture type               -string png

	# remove drop shadow from window screenshots
	_set com.apple.screencapture disable-shadow     -bool  true

	# hide the floating thumbnail after capture
	_set com.apple.screencapture show-thumbnail     -bool  false

	success "Screenshots: done"
}

apply_global() {
	info "Applying: Global"

	# save new documents to disk by default, not iCloud
	_set NSGlobalDomain NSDocumentSaveNewDocumentsToCloud      -bool false

	# expand save panel by default
	_set NSGlobalDomain NSNavPanelExpandedStateForSaveMode     -bool true
	_set NSGlobalDomain NSNavPanelExpandedStateForSaveMode2    -bool true

	# expand print panel by default
	_set NSGlobalDomain PMPrintingExpandedStateForPrint        -bool true
	_set NSGlobalDomain PMPrintingExpandedStateForPrint2       -bool true

	# disable the crash reporter dialog
	_set com.apple.CrashReporter DialogType                    -string none

	# show battery percentage in menu bar
	_set com.apple.menuextra.battery ShowPercent               -bool  true

	# allow quitting Finder via ⌘Q
	_set com.apple.finder QuitMenuItem                         -bool  true

	success "Global: done"
}

# =============================================================================
# main
# =============================================================================

main() {
	parse_args "$@" || return $?

	if [[ "$(uname -s)" != "Darwin" ]]; then
		error "This script is macOS only."
		return $EXIT_INVALID_USAGE
	fi

	if [[ "$DRY_RUN" == true ]]; then
		warn "Dry-run mode — no changes will be applied"
	else
		confirm_prompt "Apply macOS system preferences? Some changes require a logout to take full effect." \
			|| { info "Aborted."; return $EXIT_SUCCESS; }
	fi

	local start_time
	start_time=$(date +%s)

	[[ "$DO_DOCK"        == true ]] && apply_dock
	[[ "$DO_FINDER"      == true ]] && apply_finder
	[[ "$DO_KEYBOARD"    == true ]] && apply_keyboard
	[[ "$DO_SCREENSHOTS" == true ]] && apply_screenshots
	[[ "$DO_GLOBAL"      == true ]] && apply_global

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
