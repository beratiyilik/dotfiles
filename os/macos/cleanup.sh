#!/usr/bin/env bash
# =============================================================================
# cleanup.sh — system cleanup script (macOS)
#
# Description:
#   Removes development cruft and caches across the machine. Every target is
#   opt-in; the file-tree targets (--ds, --swap, --py) act under CWD and refuse
#   to run from $HOME. Mirror this in os/linux/cleanup.sh when implementing it.
#
# Usage:
#   cleanup.sh [OPTIONS] [TARGETS]
#
# Targets:
#   --ds        Remove .DS_Store files under CWD (do not run from ~)
#   --swap      Remove Vim swap files under CWD (do not run from ~)
#   --py        Remove Python cache files under CWD (__pycache__, *.pyc, *.pyo, *.pyd) (do not run from ~)
#   --trash     Empty user and volume trash
#   --logs      Clean ASL logs and quarantine events DB
#   --tmp       Securely wipe /tmp, $TMPDIR, $TEMP_DIR contents
#   -a, --all   Run all targets
#
# Options:
#   -y, --yes       Auto-confirm all prompts
#   -d, --dry-run   Show what would be removed without removing anything
#   -s, --silent    Suppress all output except errors
#   -v, --verbose   Enable verbose output (default)
#   -h, --help      Show this help and exit
#
# Dependencies:
#   - find, rm (coreutils); sqlite3 (quarantine events DB)
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
YES=false

# targets (set by parse_args)
CLEAN_DS=false
CLEAN_SWAP=false
CLEAN_PY=false
CLEAN_TRASH=false
CLEAN_LOGS=false
CLEAN_TMP=false

# =============================================================================
# help
# =============================================================================

show_help() {
	cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS] [TARGETS]

Targets (at least one required):
  --ds              Remove .DS_Store files under CWD (do not run from ~)
  --swap            Remove Vim swap files under CWD (do not run from ~)
  --py, --python    Remove Python cache files under CWD (__pycache__, *.pyc, *.pyo, *.pyd) (do not run from ~)
  --trash           Empty trash (user home + all mounted volumes)
  --logs            Clean ASL logs and quarantine events DB
  --tmp             Securely wipe /tmp, \$TMPDIR, \$TEMP_DIR contents
                    (irreversible; 3-pass overwrite — see NOTE below)
  -a, --all         Run all targets

Options:
  -y, --yes         Auto-confirm all prompts
  -d, --dry-run     Show what would be removed without removing anything
  -s, --silent      Suppress all output except errors
  -v, --verbose     Enable verbose output (default; overrides --silent)
  -h, --help        Show this help and exit

NOTE (--tmp):
  -P performs a 3-pass overwrite as a best-effort security measure.
  On SSD/APFS/NVMe (standard on modern Macs), wear leveling and
  copy-on-write semantics mean physical overwrite is NOT guaranteed.
  For true secure erasure use full-disk encryption (FileVault).

Examples:
  ${SCRIPT_NAME} --ds --swap
  ${SCRIPT_NAME} -a --yes
  ${SCRIPT_NAME} --trash --dry-run
  ${SCRIPT_NAME} --tmp --dry-run

EOF
}

# =============================================================================
# parse_args
# =============================================================================

parse_args() {
	DRY_RUN=false
	SILENT=false
	VERBOSE=true
	YES=false

	CLEAN_DS=false
	CLEAN_SWAP=false
	CLEAN_PY=false
	CLEAN_TRASH=false
	CLEAN_LOGS=false
	CLEAN_TMP=false

	if (( $# == 0 )); then
		show_help
		exit $EXIT_SUCCESS
	fi

	while (( $# > 0 )); do
		case "$1" in
		--ds)            CLEAN_DS=true ;;
		--swap)          CLEAN_SWAP=true ;;
		--py | --python) CLEAN_PY=true ;;
		--trash)         CLEAN_TRASH=true ;;
		--logs)          CLEAN_LOGS=true ;;
		--tmp)           CLEAN_TMP=true ;;
		-a | --all)
			CLEAN_DS=true
			CLEAN_SWAP=true
			CLEAN_PY=true
			CLEAN_TRASH=true
			CLEAN_LOGS=true
			CLEAN_TMP=true
			;;
		-y | --yes)     YES=true ;;
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

	if [[ "$CLEAN_DS"    == false && "$CLEAN_SWAP" == false && "$CLEAN_PY"    == false \
		&& "$CLEAN_TRASH" == false && "$CLEAN_LOGS" == false && "$CLEAN_TMP" == false ]]; then
		error "No target specified; use --ds, --swap, --py, --trash, --logs, --tmp, or -a"
		show_help
		return $EXIT_INVALID_USAGE
	fi

	return $EXIT_SUCCESS
}

# =============================================================================
# cleanup functions
# =============================================================================

# clean_ds — remove .DS_Store files under CWD
clean_ds() {
	debug "Starting: .DS_Store cleanup"
	if [[ "$PWD" == "$HOME" ]]; then
		warn "Skipping --ds: do not run from home directory"
		return $EXIT_SUCCESS
	fi
	info "Searching for .DS_Store files..."
	local found
	found=$(find . -type f -name '.DS_Store' 2>/dev/null)

	if [[ -z "$found" ]]; then
		success "No .DS_Store files found"
		return $EXIT_SUCCESS
	fi

	local count
	count=$(echo "$found" | wc -l | tr -d ' ')
	info "Found $count .DS_Store file(s)"

	if [[ "$DRY_RUN" == true ]]; then
		echo "$found" | while IFS= read -r f; do
			info "[DRY-RUN] Would remove: $f"
		done
		return $EXIT_SUCCESS
	fi

	echo "$found" | while IFS= read -r f; do
		[[ "$VERBOSE" == true ]] && debug "Removing: $f"
		if [[ -w "$f" ]]; then
			rm -f "$f" 2>/dev/null || warn "Failed to remove: $f"
		else
			sudo rm -f "$f" 2>/dev/null || warn "Failed to remove (sudo): $f"
		fi
	done

	success "Removed $count .DS_Store file(s)"
	return $EXIT_SUCCESS
}

# clean_swap — remove Vim swap files under CWD
clean_swap() {
	debug "Starting: Vim swap file cleanup"
	if [[ "$PWD" == "$HOME" ]]; then
		warn "Skipping --swap: do not run from home directory"
		return $EXIT_SUCCESS
	fi
	info "Searching for Vim swap files..."
	local found
	# parentheses required: without them -type f binds only to the first -name term
	found=$(find . \( -type f -name '*.sw[a-p]' \) -o \( -type f -name '.*.sw[a-p]' \) 2>/dev/null)

	if [[ -z "$found" ]]; then
		success "No Vim swap files found"
		return $EXIT_SUCCESS
	fi

	local count
	count=$(echo "$found" | wc -l | tr -d ' ')
	info "Found $count swap file(s)"

	if [[ "$DRY_RUN" == true ]]; then
		echo "$found" | while IFS= read -r f; do
			info "[DRY-RUN] Would remove: $f"
		done
		return $EXIT_SUCCESS
	fi

	echo "$found" | while IFS= read -r f; do
		[[ "$VERBOSE" == true ]] && debug "Removing: $f"
		rm -f "$f" 2>/dev/null || warn "Failed to remove: $f"
	done

	success "Removed $count swap file(s)"
	return $EXIT_SUCCESS
}

# clean_py — remove Python cache files under CWD
clean_py() {
	debug "Starting: Python cache cleanup"
	if [[ "$PWD" == "$HOME" ]]; then
		warn "Skipping --py: do not run from home directory"
		return $EXIT_SUCCESS
	fi
	info "Searching for Python cache files..."
	local found_files found_dirs
	found_files=$(find . \( -type f -name '*.pyc' -o -type f -name '*.pyo' -o -type f -name '*.pyd' \) 2>/dev/null)
	found_dirs=$(find . -type d -name '__pycache__' 2>/dev/null)

	local file_count=0 dir_count=0
	[[ -n "$found_files" ]] && file_count=$(echo "$found_files" | wc -l | tr -d ' ')
	[[ -n "$found_dirs"  ]] && dir_count=$(echo "$found_dirs"  | wc -l | tr -d ' ')

	if (( file_count == 0 && dir_count == 0 )); then
		success "No Python cache files found"
		return $EXIT_SUCCESS
	fi

	info "Found ${file_count} cache file(s) and ${dir_count} __pycache__ director(ies)"

	if [[ "$DRY_RUN" == true ]]; then
		[[ -n "$found_files" ]] && echo "$found_files" | while IFS= read -r f; do
			info "[DRY-RUN] Would remove: $f"
		done
		[[ -n "$found_dirs" ]] && echo "$found_dirs" | while IFS= read -r d; do
			info "[DRY-RUN] Would remove: $d"
		done
		return $EXIT_SUCCESS
	fi

	# remove files first so find does not descend into dirs that will be deleted
	[[ -n "$found_files" ]] && echo "$found_files" | while IFS= read -r f; do
		[[ "$VERBOSE" == true ]] && debug "Removing: $f"
		rm -f "$f" 2>/dev/null || warn "Failed to remove: $f"
	done

	[[ -n "$found_dirs" ]] && echo "$found_dirs" | while IFS= read -r d; do
		[[ "$VERBOSE" == true ]] && debug "Removing: $d"
		rm -rf "$d" 2>/dev/null || warn "Failed to remove: $d"
	done

	success "Removed ${file_count} cache file(s) and ${dir_count} __pycache__ director(ies)"
	return $EXIT_SUCCESS
}

# clean_trash — empty user trash and volume trash directories
clean_trash() {
	debug "Starting: trash cleanup"

	if ! confirm_prompt "Empty trash? This cannot be undone."; then
		info "Skipping trash cleanup"
		return $EXIT_SUCCESS
	fi

	# user trash
	local user_trash="${HOME}/.Trash"
	if [[ -d "$user_trash" ]]; then
		info "Emptying user trash..."
		local trash_contents
		trash_contents=$(find "$user_trash" -mindepth 1 -maxdepth 1 2>/dev/null)
		if [[ -z "$trash_contents" ]]; then
			info "User trash is already empty"
		elif [[ "$DRY_RUN" == true ]]; then
			echo "$trash_contents" | while IFS= read -r f; do
				info "[DRY-RUN] Would remove: $f"
			done
		else
			run_cmd sudo rm -rf "${user_trash}"/* 2>/dev/null || true
			success "User trash emptied"
		fi
	else
		debug "User trash not found: $user_trash"
	fi

	# volume trash
	info "Emptying volume trash directories..."
	local vol_trash_list
	vol_trash_list=$(find /Volumes -type d -name '.Trashes' 2>/dev/null)

	if [[ -z "$vol_trash_list" ]]; then
		debug "No volume trash directories found"
		return $EXIT_SUCCESS
	fi

	echo "$vol_trash_list" | while IFS= read -r trashdir; do
		local contents
		contents=$(find "$trashdir" -mindepth 1 -maxdepth 1 2>/dev/null)
		if [[ -z "$contents" ]]; then
			debug "$trashdir is already empty"
			continue
		fi
		if [[ "$DRY_RUN" == true ]]; then
			echo "$contents" | while IFS= read -r f; do
				info "[DRY-RUN] Would remove: $f"
			done
		else
			[[ "$VERBOSE" == true ]] && debug "Emptying: $trashdir"
			run_cmd sudo rm -rf "${trashdir}"/* 2>/dev/null || true
		fi
	done

	[[ "$DRY_RUN" == false ]] && success "Volume trash emptied"
	return $EXIT_SUCCESS
}

# clean_logs — remove ASL logs and quarantine events DB
clean_logs() {
	debug "Starting: system log cleanup"

	if ! confirm_prompt "Clean system logs? This cannot be undone."; then
		info "Skipping log cleanup"
		return $EXIT_SUCCESS
	fi

	# ASL logs
	info "Cleaning ASL logs..."
	local asl_found
	asl_found=$(find /private/var/log/asl -type f -name '*.asl' 2>/dev/null)

	if [[ -z "$asl_found" ]]; then
		info "No ASL log files found"
	elif [[ "$DRY_RUN" == true ]]; then
		echo "$asl_found" | while IFS= read -r f; do
			info "[DRY-RUN] Would remove: $f"
		done
	else
		echo "$asl_found" | while IFS= read -r f; do
			[[ "$VERBOSE" == true ]] && debug "Removing: $f"
			run_cmd sudo rm -f "$f" 2>/dev/null || warn "Failed to remove: $f"
		done
		success "ASL logs cleaned"
	fi

	# quarantine events DB
	# nullglob (set at top) — no error if no match
	info "Cleaning quarantine events database..."
	local -a qdb_files
	qdb_files=( "${HOME}"/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* )

	if (( ${#qdb_files[@]} == 0 )); then
		info "No quarantine events database found"
	else
		local qdb="${qdb_files[0]}"
		if [[ "$DRY_RUN" == true ]]; then
			info "[DRY-RUN] Would clear quarantine DB: $qdb"
		elif has_cmd sqlite3; then
			run_cmd sqlite3 "$qdb" 'DELETE FROM LSQuarantineEvent;' 2>/dev/null \
				&& success "Quarantine events DB cleared: $qdb" \
				|| warn "Failed to clear quarantine DB: $qdb"
		else
			warn "sqlite3 not found; skipping quarantine DB cleanup"
		fi
	fi

	return $EXIT_SUCCESS
}

# clean_tmp — securely wipe contents of /tmp, $TMPDIR, $TEMP_DIR
#
# Files are removed with rm -Pf (3-pass overwrite).
# Directories and non-regular files are removed with rm -rf after file wipe.
# The directories themselves are preserved.
# Refuses to wipe known critical system paths even if they are somehow set
# as TMPDIR or TEMP_DIR.
clean_tmp() {
	debug "Starting: temp directory secure wipe"

	# build candidate list — use ${VAR:-} to safely handle unset variables
	local -a tmp_dirs=()
	tmp_dirs+=( "/tmp" )

	# $TMPDIR — macOS sets this automatically (typically /var/folders/...)
	if [[ -n "${TMPDIR:-}" && "${TMPDIR}" != "/tmp" ]]; then
		# tmp_dirs+=( "${TMPDIR}" )
		warn "\$TMPDIR skipped (macOS sets this to /var/folders/…; wiping it breaks Finder and other apps)"
	fi

	# $TEMP_DIR — user-defined; skip if unset, empty, or duplicate
	if [[ -n "${TEMP_DIR:-}" \
		&& "${TEMP_DIR}" != "/tmp" \
		&& "${TEMP_DIR}" != "${TMPDIR:-}" ]]; then
		tmp_dirs+=( "${TEMP_DIR}" )
	fi

	# safety: refuse to wipe critical system paths
	local -a forbidden=( "/" "/System" "/usr" "/bin" "/sbin" "/etc" "/var" "${HOME}" )

	local dir
	for dir in "${tmp_dirs[@]}"; do
		local real_dir
		real_dir=$(realpath "$dir" 2>/dev/null || echo "$dir")

		# forbidden path check
		local forbidden_path
		for forbidden_path in "${forbidden[@]}"; do
			if [[ "$real_dir" == "$forbidden_path" ]]; then
				error "Refusing to wipe forbidden path: $real_dir"
				continue 2
			fi
		done

		if [[ ! -d "$real_dir" ]]; then
			debug "Directory does not exist; skipping: $real_dir"
			continue
		fi

		local contents
		contents=$(find "$real_dir" -mindepth 1 -maxdepth 1 2>/dev/null)
		if [[ -z "$contents" ]]; then
			info "$real_dir is already empty"
			continue
		fi

		local count
		count=$(echo "$contents" | wc -l | tr -d ' ')
		warn "$count item(s) in $real_dir will be wiped irreversibly (3-pass overwrite)"

		if ! confirm_prompt "Securely wipe all contents of $real_dir?"; then
			info "Skipping: $real_dir"
			continue
		fi

		if [[ "$DRY_RUN" == true ]]; then
			echo "$contents" | while IFS= read -r f; do
				info "[DRY-RUN] Would securely remove: $f"
			done
			continue
		fi

		info "Securely wiping: $real_dir"

		# wipe regular files first with 3-pass overwrite
		find "$real_dir" -mindepth 1 -type f 2>/dev/null | while IFS= read -r f; do
			[[ "$VERBOSE" == true ]] && debug "Wiping: $f"
			rm -Pf "$f" 2>/dev/null || warn "Failed to wipe: $f"
		done

		# remove remaining entries (dirs, symlinks, sockets, etc.)
		find "$real_dir" -mindepth 1 -depth -not -type f 2>/dev/null | while IFS= read -r f; do
			[[ "$VERBOSE" == true ]] && debug "Removing: $f"
			rm -rf "$f" 2>/dev/null || warn "Failed to remove: $f"
		done

		success "Securely wiped: $real_dir"
	done

	return $EXIT_SUCCESS
}

# =============================================================================
# main
# =============================================================================

main() {
	parse_args "$@" || return $?

	debug "DRY_RUN=$DRY_RUN SILENT=$SILENT VERBOSE=$VERBOSE YES=$YES"
	debug "Targets: DS=$CLEAN_DS SWAP=$CLEAN_SWAP PY=$CLEAN_PY TRASH=$CLEAN_TRASH LOGS=$CLEAN_LOGS TMP=$CLEAN_TMP"
	[[ "$DRY_RUN" == true ]] && warn "Dry-run mode — no changes will be made"

	local start_time
	start_time=$(date +%s)

	# sudo keep-alive only when targets that require it are selected
	if [[ "$CLEAN_TRASH" == true || "$CLEAN_LOGS" == true || "$CLEAN_TMP" == true ]]; then
		trap sudo_keepalive_stop EXIT INT TERM
		sudo_keepalive_start || warn "Could not acquire sudo credentials; privileged operations may fail"
	fi

	[[ "$CLEAN_DS"    == true ]] && clean_ds
	[[ "$CLEAN_SWAP"  == true ]] && clean_swap
	[[ "$CLEAN_PY"    == true ]] && clean_py
	[[ "$CLEAN_TRASH" == true ]] && clean_trash
	[[ "$CLEAN_LOGS"  == true ]] && clean_logs
	[[ "$CLEAN_TMP"   == true ]] && clean_tmp

	sudo_keepalive_stop

	success "Cleanup completed in $(elapsed_time "$start_time")"
	return $EXIT_SUCCESS
}

main "$@"
exit $?

## eof
