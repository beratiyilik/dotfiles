#!/usr/bin/env zsh
# =============================================================================
# update.zsh — system-wide package and software update script (macOS)
#
# Usage:
#   update.zsh [OPTIONS]
#
# Updates (in order):
#   1. macOS system software (softwareupdate)
#   2. Mac App Store apps (mas)
#   3. Homebrew formulae and casks
#   4. Node.js global packages (pnpm or npm, nvm-aware)
#   5. Ruby gems
#   6. Python pip packages
#
# Options:
#   -y, --yes       Auto-confirm all prompts
#   -d, --dry-run   Show what would run without executing anything
#   -f, --force     Bypass safety checks (e.g. sudo prompt)
#   -s, --silent    Suppress all output except errors
#   -v, --verbose   Enable verbose output (default)
#   -h, --help      Show this help and exit
# =============================================================================

# must be executed directly, not sourced
[[ "${(%):-%x}" != "$0" ]] && { printf "[ERROR] Do not source this script\n" >&2; exit 64; }

# load shared utilities
source "${0:A:h}/_lib.zsh"

# =============================================================================
# configuration
# =============================================================================

DRY_RUN=false
FORCE=false
SILENT=false
VERBOSE=true
YES=false

# =============================================================================
# help
# =============================================================================

show_help() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -y, --yes           Auto-confirm all prompts (non-interactive mode)
  -d, --dry-run       Show what would run without executing anything
  -f, --force         Bypass safety checks (e.g. allow interactive sudo prompt)
  -s, --silent        Suppress all output except errors
  -v, --verbose       Enable verbose output (default; overrides --silent)
  -h, --help          Show this help and exit

Notes:
  --silent and --verbose are mutually exclusive; last one wins.
  --force should be used with caution; it overrides safety mechanisms.
  --yes skips all confirmation prompts.

Examples:
  $(basename "$0") --dry-run
  $(basename "$0") --yes --silent
  $(basename "$0") --force --verbose

EOF
}

# =============================================================================
# parse_args
# =============================================================================

parse_args() {
	DRY_RUN=false
	FORCE=false
	SILENT=false
	VERBOSE=true
	YES=false

	while (( $# > 0 )); do
		case "$1" in
		-y | --yes)     YES=true ;;
		-d | --dry-run) DRY_RUN=true ;;
		-f | --force)   FORCE=true ;;
		-s | --silent)
			SILENT=true
			VERBOSE=false
			;;
		-v | --verbose)
			VERBOSE=true
			SILENT=false
			;;
		-h | --help)
			show_help
			exit $EXIT_SUCCESS
			;;
		-* | --*)
			error "Unknown option: $1"
			show_help
			return $EXIT_INVALID_USAGE
			;;
		*)
			error "Unexpected argument: $1"
			show_help
			return $EXIT_INVALID_USAGE
			;;
		esac
		shift
	done

	return $EXIT_SUCCESS
}

# =============================================================================
# update functions
# =============================================================================

# update_macos — macOS system software via softwareupdate
update_macos() {
	debug "Starting: macOS system updates"

	if ! command -v softwareupdate &>/dev/null; then
		error "softwareupdate not found"
		return $EXIT_CMD_NOT_FOUND
	fi

	info "Checking for macOS system updates..."
	local updates
	if ! updates=$(softwareupdate -l 2>&1); then
		error "Failed to check for updates: $updates"
		return $EXIT_INVALID_USAGE
	fi

	if [[ "$updates" == *"No new software available"* ]]; then
		success "No macOS updates available"
		return $EXIT_SUCCESS
	fi

	info "Available updates:"
	printf "%s\n" "$updates"

	if ! confirm_prompt "Install macOS updates?"; then
		info "Skipping macOS updates"
		return $EXIT_SUCCESS
	fi

	# sudo_keepalive covers the session; -n ensures we fail fast if it lapsed
	if ! sudo -n true 2>/dev/null; then
		if [[ "$FORCE" == true ]]; then
			warn "sudo requires a password — prompting (--force active)"
		else
			error "sudo requires a password; skipping macOS updates (use --force to prompt)"
			return $EXIT_AUTH_FAILED
		fi
	fi

	if ! run_cmd sudo softwareupdate -i -a 2>&1; then
		warn "Some updates may have failed to install"
	else
		success "macOS system updates installed"
	fi

	if [[ "$updates" == *"restart"* || "$updates" == *"Restart"* ]]; then
		warn "A system restart may be required to complete the updates"
	fi

	success "macOS system updates completed"
	return $EXIT_SUCCESS
}

# update_mas — Mac App Store apps via mas-cli
update_mas() {
	debug "Starting: App Store updates"

	if ! command -v mas &>/dev/null; then
		warn "mas not found; skipping App Store updates (install with: brew install mas)"
		return $EXIT_SUCCESS
	fi

	info "Checking App Store authentication..."
	local account_info
	account_info=$(mas account 2>&1)
	if [[ "$account_info" == *@* ]]; then
		debug "Signed in to App Store as: $account_info"
	else
		debug "mas account: not signed in — attempting to continue"
	fi

	info "Checking for App Store updates..."
	local outdated
	local outdated_rc
	outdated=$(mas outdated 2>&1)
	outdated_rc=$?

	if (( outdated_rc != 0 )); then
		if echo "$outdated" | grep -qiE 'authentication|signed in'; then
			error "App Store authentication error: $outdated"
			warn "Open the App Store app, sign in manually, then retry"
			return $EXIT_AUTH_FAILED
		else
			error "mas outdated failed: $outdated"
			return $EXIT_INVALID_USAGE
		fi
	fi

	if [[ -z "$outdated" ]]; then
		success "No App Store updates available"
		return $EXIT_SUCCESS
	fi

	debug "Outdated apps:"
	while IFS= read -r line; do
		debug "  $line"
	done <<< "$outdated"

	if ! confirm_prompt "Install App Store updates?"; then
		info "Skipping App Store updates"
		return $EXIT_SUCCESS
	fi

	info "Installing App Store updates..."
	local upgrade_output
	local upgrade_rc
	upgrade_output=$(run_cmd mas upgrade 2>&1)
	upgrade_rc=$?

	if (( upgrade_rc != 0 )); then
		if echo "$upgrade_output" | grep -qiE 'authentication|signed in'; then
			error "App Store authentication failed during upgrade: $upgrade_output"
			warn "Open the App Store app, sign in manually, then retry"
		else
			warn "Some App Store updates failed: $upgrade_output"
		fi
	else
		success "App Store updates installed"
	fi

	success "App Store updates completed"
	return $EXIT_SUCCESS
}

# update_brew — Homebrew formulae, casks, and maintenance tasks
update_brew() {
	debug "Starting: Homebrew updates"

	if ! command -v brew &>/dev/null; then
		warn "brew not found; skipping Homebrew updates"
		return $EXIT_SUCCESS
	fi

	# 1. fetch latest package metadata
	info "1. Updating Homebrew..."
	if ! run_cmd brew update; then
		error "brew update failed"
		return $EXIT_INVALID_USAGE
	fi

	# 2. upgrade all formulae and casks
	# brew upgrade covers casks since Homebrew 2.6; --cask is redundant
	info "2. Upgrading packages..."
	run_cmd brew upgrade || warn "brew upgrade reported errors; continuing"

	# 3. remove stale versions and cached downloads
	info "3. Cleaning up old versions and cache..."
	run_cmd brew cleanup -s || true

	# 4. remove formulae that are no longer dependencies
	info "4. Removing unused dependencies..."
	run_cmd brew autoremove || true

	# 5. run brew doctor — capture output once, reused in step 8
	info "5. Running brew doctor..."
	local doctor_output
	doctor_output=$(brew doctor 2>&1) || true
	if [[ -n "$doctor_output" ]]; then
		warn "brew doctor output:"
		warn "$doctor_output"
	else
		success "brew doctor: no issues found"
	fi

	# 6. warn on known deprecated formulae
	info "6. Checking for deprecated formulae..."
	local -a deprecated_pkgs=("tldr")
	local installed_formulae
	installed_formulae=$(brew list --formula 2>/dev/null)
	local pkg
	for pkg in "${deprecated_pkgs[@]}"; do
		if echo "$installed_formulae" | grep -q "^${pkg}$"; then
			warn "'${pkg}' is deprecated; consider replacing or removing it"
		fi
	done

	# 7. untap unused official taps
	info "7. Removing unused official taps..."
	local active_taps
	active_taps=$(brew tap 2>/dev/null)
	local tap
	for tap in homebrew/bundle homebrew/services; do
		if echo "$active_taps" | grep -q "^${tap}$"; then
			warn "Untapping: $tap"
			run_cmd brew untap "$tap" || true
		fi
	done

	# 8. report unlinked kegs using doctor_output from step 5
	info "8. Checking for unlinked kegs..."
	local unlinked_kegs
	unlinked_kegs=$(echo "$doctor_output" | grep '^  ' | awk '{$1=$1};1')
	if [[ -n "$unlinked_kegs" ]]; then
		warn "Unlinked kegs detected:"
		warn "$unlinked_kegs"
		warn "To link manually:"
		while IFS= read -r keg; do
			warn "  brew link $keg"
		done <<< "$unlinked_kegs"
	else
		success "All kegs are properly linked"
	fi

	# 9. list remaining outdated packages (informational)
	info "9. Checking for remaining outdated packages..."
	run_cmd brew outdated || success "All packages are up to date"

	# 10. check for missing dependencies
	info "10. Checking for missing dependencies..."
	run_cmd brew missing || success "No missing dependencies"

	# 11. list installed formulae
	info "11. Installed formulae:"
	brew list

	success "Homebrew updates completed"
	return $EXIT_SUCCESS
}

# update_node — global Node.js packages via pnpm (preferred) or npm
# nvm-aware: logs the active Node version when nvm is in use
update_node() {
	debug "Starting: Node.js global package updates"

	if command -v pnpm &>/dev/null; then
		info "Updating global pnpm packages..."
		run_cmd pnpm -g update \
			&& success "pnpm global packages updated" \
			|| warn "pnpm global update reported errors; continuing"

	elif command -v npm &>/dev/null; then
		if command -v nvm &>/dev/null; then
			local node_version
			node_version=$(nvm current 2>/dev/null || echo "unknown")
			debug "nvm active Node version: $node_version"
		fi

		info "Updating global npm packages..."
		run_cmd npm -g update \
			&& success "npm global packages updated" \
			|| warn "npm global update reported errors; continuing"

	else
		debug "Neither pnpm nor npm found; skipping Node.js updates"
	fi

	return $EXIT_SUCCESS
}

# update_ruby — RubyGems system and installed gems
update_ruby() {
	debug "Starting: Ruby gem updates"

	if ! command -v gem &>/dev/null; then
		debug "gem not found; skipping Ruby updates"
		return $EXIT_SUCCESS
	fi

	local gem_dir
	gem_dir=$(gem environment gemdir 2>/dev/null)

	if [[ ! -w "$gem_dir" ]]; then
		warn "No write permission to gem directory: $gem_dir"
		warn "Consider using rbenv or rvm to manage Ruby versions"
		if [[ "$YES" == true ]]; then
			warn "Skipping Ruby updates (auto-yes + no write permission)"
			return $EXIT_SUCCESS
		fi
		if ! confirm_prompt "Continue with gem operations anyway?"; then
			info "Skipping Ruby updates"
			return $EXIT_SUCCESS
		fi
	fi

	info "Updating RubyGems system..."
	run_cmd gem update --system \
		|| warn "gem update --system reported errors; continuing"

	info "Updating installed gems..."
	run_cmd gem update \
		|| warn "gem update reported errors; continuing"

	info "Cleaning up old gem versions..."
	run_cmd gem cleanup || true

	success "Ruby gem updates completed"
	return $EXIT_SUCCESS
}

# update_python — pip self-upgrade and outdated package upgrades
update_python() {
	debug "Starting: Python pip updates"

	if ! command -v pip &>/dev/null; then
		debug "pip not found; skipping Python updates"
		return $EXIT_SUCCESS
	fi

	info "Upgrading pip..."
	run_cmd pip install --upgrade pip \
		|| warn "pip self-upgrade reported errors; continuing"

	info "Checking for outdated pip packages..."
	local outdated
	outdated=$(pip list --outdated --format=freeze 2>/dev/null | grep -v '^\-e' | cut -d= -f1)

	if [[ -z "$outdated" ]]; then
		success "All pip packages are up to date"
		return $EXIT_SUCCESS
	fi

	printf "%s\n" "$outdated"

	if ! confirm_prompt "Upgrade outdated Python packages?"; then
		info "Skipping Python package upgrades"
		return $EXIT_SUCCESS
	fi

	echo "$outdated" | while IFS= read -r pkg; do
		run_cmd pip install --upgrade "$pkg" || warn "Failed to upgrade: $pkg"
	done

	success "Python pip updates completed"
	return $EXIT_SUCCESS
}

# =============================================================================
# main
# =============================================================================

main() {
	parse_args "$@" || return $?

	debug "DRY_RUN=$DRY_RUN FORCE=$FORCE SILENT=$SILENT VERBOSE=$VERBOSE YES=$YES"
	[[ "$DRY_RUN" == true ]] && warn "Dry-run mode — no changes will be made"

	local start_time
	start_time=$(date +%s)

	trap sudo_keepalive_stop EXIT INT TERM
	sudo_keepalive_start || warn "Could not acquire sudo credentials; privileged operations may fail"

	update_macos  || return $?
	update_mas    || return $?
	update_brew   || return $?
	update_node   || return $?
	update_ruby   || return $?
	update_python || return $?

	# Rosetta 2 check (Apple Silicon only)
	if [[ "$(uname -m)" == "arm64" ]]; then
		if /usr/bin/pgrep -q oahd 2>/dev/null; then
			debug "Rosetta 2 is installed and running"
		else
			warn "Rosetta 2 may not be installed; run: softwareupdate --install-rosetta"
		fi
	fi

	sudo_keepalive_stop

	success "All updates completed in $(elapsed_time "$start_time")"
	return $EXIT_SUCCESS
}

main "$@"
exit $?

## eof