#!/usr/bin/env bash
# =============================================================================
# snapshot.sh — macOS environment inventory snapshot
#
# Description:
#   Dumps a timestamped, read-only inventory of the machine: one .txt file per
#   section plus a combined snapshot.txt summary. This is a forensic record
#   (what the system looked like), NOT a re-appliable config. For re-appliable
#   macOS preferences see os/macos/defaults.sh + defaults.conf.
#
#   Not to be confused with core/backup.sh, which copies real files to
#   $DOTFILES/backups/backup_<stamp>/ before symlinking (the `dotfiles backup`
#   command). Snapshots land in $DOTFILES/backups/snapshot_<stamp>/.
#
# Usage:
#   snapshot.sh [OPTIONS]
#
# Sections:
#   --system      System and hardware info
#   --network     Network configuration
#   --env         Shell environment and dotfiles inventory
#   --apps        Installed applications (GUI + App Store)
#   --brew        Homebrew formulae, casks, Brewfile
#   --node        Node.js versions and global packages
#   --python      Python versions and pip packages
#   --ruby        Ruby gem list
#   --dotnet      .NET global tools
#   --vscode      VS Code extensions and settings
#   --browsers    Browser extensions (Chrome, Brave, Safari)
#   --crontab     Crontab entries
#   --defaults    macOS system defaults (Dock, Finder, keyboard, etc.)
#   -a, --all     Run all sections (default when no section is given)
#
# Options:
#   -o, --output <dir>   Base output directory (default: $DOTFILES/backups);
#                        the run lands in <dir>/snapshot_<stamp>/
#   -d, --dry-run        Show what would run without writing any files
#   -s, --silent         Suppress all output except errors
#   -v, --verbose        Enable verbose output (default)
#   -h, --help           Show this help and exit
#
# Dependencies:
#   - All section tools are optional; a section is skipped when its tool is
#     absent. Reads from system_profiler, defaults, brew, npm/pnpm/yarn,
#     pip/pyenv, gem, dotnet, code, jq when present.
#
# Return Codes:
#   0    Success
#   64   Invalid usage (unknown option)
# =============================================================================

# must be executed directly, not sourced
[[ "${BASH_SOURCE[0]}" != "$0" ]] && { printf "[ERROR] Do not source this script\n" >&2; exit 64; }

# load shared utilities (lives one level up: os/lib.sh, shared across OSes)
LIB_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/../lib.sh"
source "$LIB_DIR/../../core/paths.sh"   # DF_BACKUPS_ROOT, df_backup_stamp, df_backup_dir

# unmatched globs expand to nothing (parity with zsh (N) qualifier used below)
shopt -s nullglob

# basename of this script
SCRIPT_NAME="$(basename "$0")"

# =============================================================================
# configuration
# =============================================================================

DRY_RUN=false
SILENT=false
VERBOSE=true
YES=true   # backup is non-destructive; no confirmation prompts needed

OUTPUT_BASE="$DF_BACKUPS_ROOT"   # parent dir; leaf is snapshot_<stamp>. -o overrides this base
TIMESTAMP="$(df_backup_stamp)"
BACKUP_DIR=""        # resolved in main after OUTPUT_BASE is set
BACKUP_SUMMARY=""    # resolved in main

# section flags
DO_SYSTEM=false
DO_NETWORK=false
DO_ENV=false
DO_APPS=false
DO_BREW=false
DO_NODE=false
DO_PYTHON=false
DO_RUBY=false
DO_DOTNET=false
DO_VSCODE=false
DO_BROWSERS=false
DO_CRONTAB=false
DO_DEFAULTS=false

# =============================================================================
# help
# =============================================================================

show_help() {
	cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS] [SECTIONS]

Sections (default: all):
  --system      System and hardware info
  --network     Network configuration
  --env         Shell environment and dotfiles inventory
  --apps        Installed applications (GUI + App Store)
  --brew        Homebrew formulae, casks, Brewfile
  --node        Node.js versions and global packages (nvm, pnpm, npm, yarn)
  --python      Python versions and pip packages (pyenv, pip)
  --ruby        Ruby gem list
  --dotnet      .NET global tools
  --vscode      VS Code extensions and settings
  --browsers    Browser extensions (Chrome, Brave, Safari)
  --crontab     Crontab entries
  --defaults    macOS system defaults (Dock, Finder, keyboard, trackpad, etc.)
  -a, --all     Run all sections

Options:
  -o, --output <dir>   Base output directory (default: \$DOTFILES/backups);
                       the run lands in <dir>/snapshot_<stamp>/
  -d, --dry-run        Show what would run without writing any files
  -s, --silent         Suppress all output except errors
  -v, --verbose        Enable verbose output (default; overrides --silent)
  -h, --help           Show this help and exit

Output structure:
  <output-dir>/
  └── snapshot_YYYYMMDD_HHMMSS_<pid>/
      ├── system.txt
      ├── network.txt
      ├── ...
      └── snapshot.txt  (combined summary of all sections)

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --brew --node --python
  ${SCRIPT_NAME} --all --output "\$DOTFILES/backups"
  ${SCRIPT_NAME} --dry-run

EOF
}

# =============================================================================
# parse_args
# =============================================================================

parse_args() {
	DRY_RUN=false
	SILENT=false
	VERBOSE=true

	local any_section=false

	while (( $# > 0 )); do
		case "$1" in
		--system)   DO_SYSTEM=true;   any_section=true ;;
		--network)  DO_NETWORK=true;  any_section=true ;;
		--env)      DO_ENV=true;      any_section=true ;;
		--apps)     DO_APPS=true;     any_section=true ;;
		--brew)     DO_BREW=true;     any_section=true ;;
		--node)     DO_NODE=true;     any_section=true ;;
		--python)   DO_PYTHON=true;   any_section=true ;;
		--ruby)     DO_RUBY=true;     any_section=true ;;
		--dotnet)   DO_DOTNET=true;   any_section=true ;;
		--vscode)   DO_VSCODE=true;   any_section=true ;;
		--browsers) DO_BROWSERS=true; any_section=true ;;
		--crontab)  DO_CRONTAB=true;  any_section=true ;;
		--defaults) DO_DEFAULTS=true; any_section=true ;;
		-a | --all)
			DO_SYSTEM=true;  DO_NETWORK=true; DO_ENV=true
			DO_APPS=true;    DO_BREW=true;    DO_NODE=true
			DO_PYTHON=true;  DO_RUBY=true;    DO_DOTNET=true
			DO_VSCODE=true;  DO_BROWSERS=true; DO_CRONTAB=true
			DO_DEFAULTS=true
			any_section=true
			;;
		-o | --output)
			shift
			[[ -z "${1:-}" ]] && { error "--output requires a directory argument"; return $EXIT_INVALID_USAGE; }
			OUTPUT_BASE="$1"
			;;
		-d | --dry-run) DRY_RUN=true ;;
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

	# default: run all sections
	if [[ "$any_section" == false ]]; then
		DO_SYSTEM=true;  DO_NETWORK=true; DO_ENV=true
		DO_APPS=true;    DO_BREW=true;    DO_NODE=true
		DO_PYTHON=true;  DO_RUBY=true;    DO_DOTNET=true
		DO_VSCODE=true;  DO_BROWSERS=true; DO_CRONTAB=true
		DO_DEFAULTS=true
	fi

	return $EXIT_SUCCESS
}

# =============================================================================
# output helpers
# =============================================================================

# write_section <filename> <title> <body>
# Appends a titled section to the section file and to snapshot.txt.
write_section() {
	local file="${BACKUP_DIR}/${1}"
	local title="$2"
	local body="$3"

	local separator="================================================================================"
	local block
	block=$(printf "%s\n%s\n%s\n%s\n\n" "$separator" "$title" "$separator" "$body")

	if [[ "$DRY_RUN" == true ]]; then
		debug "[DRY-RUN] Would write section '$title' to $(basename "$file")"
		return 0
	fi

	printf "%s" "$block" >> "$file"
	printf "%s" "$block" >> "$BACKUP_SUMMARY"
}

# capture <cmd> [args...]
# Runs a command and returns its combined stdout+stderr output.
# Returns empty string if the command is not found.
capture() {
	local cmd="$1"
	if ! has_cmd "$cmd"; then
		printf "(command not found: %s)" "$cmd"
		return 0
	fi
	"$@" 2>&1 || true
}

# capture_path <path> <cmd> [args...]
# Like capture but checks for a file/directory path instead of a command.
capture_path() {
	local path="$1"; shift
	if [[ ! -e "$path" ]]; then
		printf "(not found: %s)" "$path"
		return 0
	fi
	"$@" 2>&1 || true
}

# =============================================================================
# section functions
# =============================================================================

# backup_system — system and hardware info
backup_system() {
	debug "Starting: system backup"
	local file="system.txt"

	write_section "$file" "SYSTEM SOFTWARE" \
		"$(capture system_profiler SPSoftwareDataType)"

	write_section "$file" "HARDWARE" \
		"$(capture system_profiler SPHardwareDataType)"

	write_section "$file" "STORAGE" \
		"$(capture system_profiler SPStorageDataType)"

	write_section "$file" "MEMORY" \
		"$(capture system_profiler SPMemoryDataType)"

	write_section "$file" "DISPLAY" \
		"$(capture system_profiler SPDisplaysDataType)"

	write_section "$file" "DISK USAGE" \
		"$(capture df -h)"

	# Rosetta 2 (Apple Silicon)
	if is_arm64; then
		local rosetta_status
		if /usr/bin/pgrep -q oahd 2>/dev/null; then
			rosetta_status="Installed and running"
		else
			rosetta_status="Not detected"
		fi
		write_section "$file" "ROSETTA 2" "$rosetta_status"
	fi

	success "System backup complete: $file"
}

# backup_network — network configuration
backup_network() {
	debug "Starting: network backup"
	local file="network.txt"

	write_section "$file" "NETWORK HARDWARE PORTS" \
		"$(capture networksetup -listallhardwareports)"

	write_section "$file" "NETWORK INTERFACES (ifconfig)" \
		"$(capture ifconfig)"

	write_section "$file" "DNS SERVERS" \
		"$(capture scutil --dns)"

	write_section "$file" "ACTIVE NETWORK SERVICES" \
		"$(capture networksetup -listallnetworkservices)"

	write_section "$file" "VPN CONFIGURATIONS" \
		"$(capture networksetup -showpppoestatus)"

	write_section "$file" "FIREWALL STATUS" \
		"$(capture /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate)"

	success "Network backup complete: $file"
}

# backup_env — shell environment and dotfiles inventory
backup_env() {
	debug "Starting: environment backup"
	local file="env.txt"

	write_section "$file" "HOME DIRECTORY" \
		"$(ls -la "${HOME}" 2>&1)"

	write_section "$file" "SHELL CONFIG FILES" \
		"$(ls -la "${HOME}"/.zshrc "${HOME}"/.zshenv "${HOME}"/.zprofile \
			"${HOME}"/.bashrc "${HOME}"/.bash_profile "${HOME}"/.profile 2>&1 || true)"

	write_section "$file" "DOTFILES DIRECTORY" \
		"$(capture_path "${DOTFILES:-$HOME/dotfiles}" ls -la "${DOTFILES:-$HOME/dotfiles}")"

	write_section "$file" "SSH KEYS" \
		"$(capture_path "${HOME}/.ssh" ls -la "${HOME}/.ssh")"

	write_section "$file" "GPG KEYS" \
		"$(capture gpg --list-keys)"

	write_section "$file" "ENVIRONMENT VARIABLES" \
		"$(env | sort 2>&1)"

	write_section "$file" "PATH" \
		"$(tr ':' '\n' <<< "$PATH")"

	write_section "$file" "SHELL" \
		"$(printf "Current shell: %s\nDefault shell: %s\n" "$SHELL" "$(dscl . -read "/Users/${USER}" UserShell 2>/dev/null | awk '{print $2}')")"

	success "Environment backup complete: $file"
}

# backup_apps — installed GUI applications and App Store apps
backup_apps() {
	debug "Starting: apps backup"
	local file="apps.txt"

	write_section "$file" "APPLICATIONS (/Applications)" \
		"$(ls /Applications 2>&1)"

	write_section "$file" "USER APPLICATIONS (~/Applications)" \
		"$(capture_path "${HOME}/Applications" ls "${HOME}/Applications")"

	write_section "$file" "APP STORE APPLICATIONS (mas)" \
		"$(capture mas list)"

	write_section "$file" "SYSTEM PACKAGES (pkgutil)" \
		"$(capture pkgutil --pkgs)"

	success "Apps backup complete: $file"
}

# backup_brew — Homebrew formulae, casks, taps, Brewfile
backup_brew() {
	debug "Starting: Homebrew backup"
	local file="brew.txt"

	if ! has_cmd brew; then
		warn "brew not found; skipping Homebrew backup"
		return $EXIT_SUCCESS
	fi

	write_section "$file" "HOMEBREW VERSION" \
		"$(brew --version 2>&1)"

	write_section "$file" "INSTALLED FORMULAE" \
		"$(brew list --formula 2>&1)"

	write_section "$file" "INSTALLED CASKS" \
		"$(brew list --cask 2>&1)"

	write_section "$file" "INSTALLED TAPS" \
		"$(brew tap 2>&1)"

	write_section "$file" "OUTDATED PACKAGES" \
		"$(brew outdated 2>&1)"

	# dump Brewfile into backup dir
	if [[ "$DRY_RUN" == false ]]; then
		brew bundle dump --file="${BACKUP_DIR}/Brewfile" --force 2>/dev/null \
			&& write_section "$file" "BREWFILE" "$(cat "${BACKUP_DIR}/Brewfile")" \
			|| warn "brew bundle dump failed"
	else
		debug "[DRY-RUN] Would write Brewfile to ${BACKUP_DIR}/Brewfile"
	fi

	success "Homebrew backup complete: $file"
}

# backup_node — Node.js versions and global packages
backup_node() {
	debug "Starting: Node.js backup"
	local file="node.txt"

	# nvm
	export NVM_DIR="${NVM_DIR:-$([ -n "$BREW_DIR" ] && [ -d "$BREW_DIR/opt/nvm" ] && echo "$BREW_DIR/opt/nvm" || echo "$HOME/.nvm")}"
	[[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh"

	if has_cmd nvm; then
		# strip ANSI color codes for clean plain-text output
		write_section "$file" "NODE.JS VERSIONS (nvm)" \
			"$(nvm ls 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
		write_section "$file" "NODE.JS ALIASES (nvm)" \
			"$(nvm alias 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
	else
		write_section "$file" "NODE.JS VERSIONS (nvm)" \
			"(nvm not found)"
	fi

	write_section "$file" "NODE VERSION" \
		"$(capture node --version)"

	# pnpm global packages
	if has_cmd pnpm; then
		write_section "$file" "PNPM GLOBAL PACKAGES" \
			"$(pnpm list -g --depth=0 2>&1)"
	fi

	# npm global packages
	if has_cmd npm; then
		write_section "$file" "NPM GLOBAL PACKAGES" \
			"$(npm list -g --depth=0 2>&1)"
	fi

	# yarn global packages (v1 only; yarn berry removed global)
	if has_cmd yarn; then
		local yarn_version
		yarn_version=$(yarn --version 2>/dev/null | cut -d. -f1)
		if [[ "$yarn_version" == "1" ]]; then
			write_section "$file" "YARN GLOBAL PACKAGES (v1)" \
				"$(yarn global list 2>&1)"
		else
			write_section "$file" "YARN VERSION" \
				"$(yarn --version 2>&1) (yarn berry — no global packages)"
		fi
	fi

	success "Node.js backup complete: $file"
}

# backup_python — Python versions and pip packages
backup_python() {
	debug "Starting: Python backup"
	local file="python.txt"

	# pyenv versions
	if has_cmd pyenv; then
		write_section "$file" "PYTHON VERSIONS (pyenv)" \
			"$(pyenv versions 2>&1)"
	fi

	write_section "$file" "PYTHON VERSION" \
		"$(capture python3 --version)"

	write_section "$file" "PIP PACKAGES" \
		"$(capture pip list)"

	write_section "$file" "PIP3 PACKAGES" \
		"$(capture pip3 list)"

	success "Python backup complete: $file"
}

# backup_ruby — Ruby version and installed gems
backup_ruby() {
	debug "Starting: Ruby backup"
	local file="ruby.txt"

	write_section "$file" "RUBY VERSION" \
		"$(capture ruby --version)"

	write_section "$file" "GEM ENVIRONMENT" \
		"$(capture gem environment)"

	write_section "$file" "INSTALLED GEMS" \
		"$(capture gem list)"

	success "Ruby backup complete: $file"
}

# backup_dotnet — .NET SDK and global tools
backup_dotnet() {
	debug "Starting: .NET backup"
	local file="dotnet.txt"

	if ! has_cmd dotnet; then
		warn "dotnet not found; skipping .NET backup"
		return $EXIT_SUCCESS
	fi

	write_section "$file" "DOTNET VERSION" \
		"$(dotnet --version 2>&1)"

	write_section "$file" "DOTNET SDKs" \
		"$(dotnet --list-sdks 2>&1)"

	write_section "$file" "DOTNET RUNTIMES" \
		"$(dotnet --list-runtimes 2>&1)"

	write_section "$file" "DOTNET GLOBAL TOOLS" \
		"$(dotnet tool list --global 2>&1)"

	success ".NET backup complete: $file"
}

# backup_vscode — VS Code extensions and settings
backup_vscode() {
	debug "Starting: VS Code backup"
	local file="vscode.txt"

	if ! has_cmd code; then
		warn "code not found; skipping VS Code backup"
		return $EXIT_SUCCESS
	fi

	write_section "$file" "VSCODE VERSION" \
		"$(code --version 2>&1)"

	write_section "$file" "VSCODE EXTENSIONS" \
		"$(code --list-extensions --show-versions 2>&1)"

	local settings_file="${HOME}/Library/Application Support/Code/User/settings.json"
	write_section "$file" "VSCODE USER SETTINGS" \
		"$(capture_path "$settings_file" cat "$settings_file")"

	local keybindings_file="${HOME}/Library/Application Support/Code/User/keybindings.json"
	write_section "$file" "VSCODE KEYBINDINGS" \
		"$(capture_path "$keybindings_file" cat "$keybindings_file")"

	local snippets_dir="${HOME}/Library/Application Support/Code/User/snippets"
	write_section "$file" "VSCODE SNIPPETS" \
		"$(capture_path "$snippets_dir" ls -la "$snippets_dir")"

	success "VS Code backup complete: $file"
}

# backup_browsers — Chrome, Brave, Safari extensions
backup_browsers() {
	debug "Starting: browser backup"
	local file="browsers.txt"

	# helper: dump Chrome-family profile extensions
	# usage: _dump_chrome_profiles <browser_label> <profiles_base_dir>
	_dump_chrome_profiles() {
		local label="$1"
		local base="$2"

		if [[ ! -d "$base" ]]; then
			write_section "$file" "${label} EXTENSIONS" "(not installed)"
			return
		fi

		local output=""

		# discover all profile directories dynamically (nullglob set at top)
		local -a profiles
		profiles=( "${base}"/Default "${base}"/Profile\ * )

		local profile
		for profile in "${profiles[@]}"; do
			[[ ! -d "$profile" ]] && continue
			local profile_name
			profile_name=$(basename "$profile")
			local prefs="${profile}/Secure Preferences"

			output+="--- ${profile_name} ---\n"

			if [[ -f "$prefs" ]] && has_cmd jq; then
				local ext_data
				ext_data=$(jq -r '
					.extensions.settings // {} |
					to_entries[] |
					# exclude Chrome internal/component extensions:
					# location 5 = component, location 10 = external component
					# keep only entries that have a manifest with a real name
					select(
						(.value.location // 0) != 5 and
						(.value.location // 0) != 10 and
						(.value.manifest.name? // "") != "" and
						(.value.manifest.name | startswith("__MSG_") | not)
					) |
					.key + " - " + .value.manifest.name +
					" (v" + (.value.manifest.version // "?") + ")"
				' "$prefs" 2>/dev/null)
				if [[ -n "$ext_data" ]]; then
					output+="${ext_data}\n"
				else
					output+="(no user-installed extensions found)\n"
				fi
			elif [[ ! -f "$prefs" ]]; then
				output+="(Secure Preferences file not found)\n"
			else
				output+="(jq not found; install with: brew install jq)\n"
			fi
			output+="\n"
		done

		write_section "$file" "${label} EXTENSIONS" "$(printf "%b" "$output")"
	}

	# Google Chrome
	_dump_chrome_profiles "GOOGLE CHROME" \
		"${HOME}/Library/Application Support/Google/Chrome"

	# Brave
	_dump_chrome_profiles "BRAVE" \
		"${HOME}/Library/Application Support/BraveSoftware/Brave-Browser"

	# Safari — modern Safari Web Extensions are registered via pluginkit,
	# not stored in ~/Library/Safari/Extensions/extensions.plist
	local safari_output
	safari_output=$(pluginkit -mAvvv -p com.apple.Safari.web-extension 2>/dev/null | \
		sed 's/^[[:space:]]*//' | \
		/usr/bin/awk '
			/^[a-z][^ ].*\(/ {
				split($0, a, "("); id=a[1]
				split(a[2], b, ")"); ver=b[1]
			}
			/^Display Name/ {
				split($0, a, " = "); print id "- " a[2] " (v" ver ")"
			}
		')

	if [[ -z "$safari_output" ]]; then
		write_section "$file" "SAFARI EXTENSIONS" "(no Safari web extensions found)"
	else
		write_section "$file" "SAFARI EXTENSIONS" "$safari_output"
	fi

	success "Browsers backup complete: $file"
}

# backup_crontab — user and root crontab entries
backup_crontab() {
	debug "Starting: crontab backup"
	local file="crontab.txt"

	write_section "$file" "USER CRONTAB (${USER})" \
		"$(crontab -l 2>&1 || printf "(no crontab for %s)" "$USER")"

	write_section "$file" "LAUNCHAGENTS (~/Library/LaunchAgents)" \
		"$(capture_path "${HOME}/Library/LaunchAgents" ls -la "${HOME}/Library/LaunchAgents")"

	write_section "$file" "LAUNCHDAEMONS (/Library/LaunchDaemons)" \
		"$(capture_path "/Library/LaunchDaemons" ls -la "/Library/LaunchDaemons")"

	write_section "$file" "LOADED LAUNCH AGENTS (launchctl)" \
		"$(launchctl list 2>&1 | head -100)"

	success "Crontab backup complete: $file"
}

# backup_defaults — macOS system preferences via defaults read
backup_defaults() {
	debug "Starting: macOS defaults backup"
	local file="defaults.txt"

	# Dock
	write_section "$file" "DOCK" \
		"$(defaults read com.apple.dock 2>&1)"

	# Finder
	write_section "$file" "FINDER" \
		"$(defaults read com.apple.finder 2>&1)"

	# Keyboard
	write_section "$file" "KEYBOARD" \
		"$(defaults read -g InitialKeyRepeat 2>&1
		defaults read -g KeyRepeat 2>&1
		defaults read -g ApplePressAndHoldEnabled 2>&1
		defaults read com.apple.keyboard 2>&1 || true)"

	# Trackpad
	write_section "$file" "TRACKPAD" \
		"$(defaults read com.apple.AppleMultitouchTrackpad 2>&1
		defaults read com.apple.trackpad 2>&1 || true)"

	# Mouse
	write_section "$file" "MOUSE" \
		"$(defaults read com.apple.AppleMultitouchMouse 2>&1
		defaults read -g com.apple.mouse.scaling 2>&1 || true)"

	# Screenshots
	write_section "$file" "SCREENSHOTS" \
		"$(defaults read com.apple.screencapture 2>&1)"

	# Energy saver / sleep
	write_section "$file" "ENERGY SAVER" \
		"$(capture pmset -g)"

	# Notification Center
	write_section "$file" "NOTIFICATION CENTER" \
		"$(defaults read com.apple.notificationcenterui 2>&1 || true)"

	# Menu bar / Control Center
	write_section "$file" "CONTROL CENTER" \
		"$(defaults read com.apple.controlcenter 2>&1 || true)"

	# Accessibility
	write_section "$file" "ACCESSIBILITY" \
		"$(defaults read com.apple.universalaccess 2>&1 || true)"

	# Sound
	write_section "$file" "SOUND" \
		"$(defaults read com.apple.sound 2>&1 || true)"

	# Global preferences
	write_section "$file" "GLOBAL PREFERENCES" \
		"$(defaults read -g 2>&1)"

	# Software Update settings
	write_section "$file" "SOFTWARE UPDATE" \
		"$(defaults read com.apple.SoftwareUpdate 2>&1 || true)"

	# Security & Privacy
	write_section "$file" "SECURITY" \
		"$(defaults read com.apple.security 2>&1 || true)"

	success "macOS defaults backup complete: $file"
}

# =============================================================================
# main
# =============================================================================

main() {
	parse_args "$@" || return $?

	BACKUP_DIR="$(df_backup_dir snapshot "$TIMESTAMP" "$OUTPUT_BASE")"
	BACKUP_SUMMARY="${BACKUP_DIR}/snapshot.txt"

	debug "DRY_RUN=$DRY_RUN SILENT=$SILENT VERBOSE=$VERBOSE"
	debug "Output: $BACKUP_DIR"
	debug "Sections: SYSTEM=$DO_SYSTEM NETWORK=$DO_NETWORK ENV=$DO_ENV APPS=$DO_APPS"
	debug "          BREW=$DO_BREW NODE=$DO_NODE PYTHON=$DO_PYTHON RUBY=$DO_RUBY"
	debug "          DOTNET=$DO_DOTNET VSCODE=$DO_VSCODE BROWSERS=$DO_BROWSERS"
	debug "          CRONTAB=$DO_CRONTAB DEFAULTS=$DO_DEFAULTS"

	if [[ "$DRY_RUN" == true ]]; then
		warn "Dry-run mode — no files will be written"
	else
		mkdir -p "$BACKUP_DIR" || { error "Failed to create backup directory: $BACKUP_DIR"; return $EXIT_INVALID_USAGE; }
		# write header to summary file
		printf "# macOS Backup\n# Generated: %s\n# Host: %s\n\n" \
			"$TIMESTAMP" "$(hostname)" > "$BACKUP_SUMMARY"
	fi

	info "Backup directory: $BACKUP_DIR"

	local start_time
	start_time=$(date +%s)

	[[ "$DO_SYSTEM"   == true ]] && backup_system
	[[ "$DO_NETWORK"  == true ]] && backup_network
	[[ "$DO_ENV"      == true ]] && backup_env
	[[ "$DO_APPS"     == true ]] && backup_apps
	[[ "$DO_BREW"     == true ]] && backup_brew
	[[ "$DO_NODE"     == true ]] && backup_node
	[[ "$DO_PYTHON"   == true ]] && backup_python
	[[ "$DO_RUBY"     == true ]] && backup_ruby
	[[ "$DO_DOTNET"   == true ]] && backup_dotnet
	[[ "$DO_VSCODE"   == true ]] && backup_vscode
	[[ "$DO_BROWSERS" == true ]] && backup_browsers
	[[ "$DO_CRONTAB"  == true ]] && backup_crontab
	[[ "$DO_DEFAULTS" == true ]] && backup_defaults

	if [[ "$DRY_RUN" == false ]]; then
		info "Backup files:"
		ls -lh "$BACKUP_DIR" 2>/dev/null | while IFS= read -r line; do
			info "  $line"
		done
	fi

	success "Backup completed in $(elapsed_time "$start_time")"
	success "Output: $BACKUP_DIR"

	return $EXIT_SUCCESS
}

main "$@"
exit $?

## eof
