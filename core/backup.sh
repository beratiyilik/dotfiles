#!/usr/bin/env bash
# Source-only library (see docs/INTERNALS.md). Idempotent.
[[ -n "${__DF_BACKUP_LOADED:-}" ]] && return 0
readonly __DF_BACKUP_LOADED=1

# Reached only via bin/dotfiles, which exports DOTFILES; fail loud if not.
: "${DOTFILES:?DOTFILES not set — run via bin/dotfiles}"
source "$DOTFILES/core/utils.sh"   # idempotent (self-guarded)
source "$DOTFILES/core/paths.sh"   # idempotent (self-guarded)

BACKUP_DIR="$(df_backup_dir backup "$(df_backup_stamp)")"

# Count of files actually copied this process. Callers (cmd_backup) read it to
# report honestly instead of announcing a directory that was never created.
# One dotfiles invocation = one process, so a plain global accumulates correctly.
__DF_BACKUP_COUNT=0

# backup_file <target> — snapshot a real file before it is clobbered.
# Skips missing targets and existing symlinks (a symlink has no content of its
# own to lose — the real file lives in the repo). Returns non-zero only on a
# genuine copy failure, so callers can distinguish "nothing to do" (0) from
# "tried and failed" (≠0).
backup_file() {
    local target="$1"
    [[ ! -e "$target" ]] && return 0
    [[ -L "$target"   ]] && return 0

    mkdir -p "$BACKUP_DIR"
    if ! cp -r "$target" "$BACKUP_DIR/"; then
        log_error "Backup failed: $target"
        return 1
    fi
    __DF_BACKUP_COUNT=$((__DF_BACKUP_COUNT + 1))
    log_warn "Backed up: $target → $BACKUP_DIR/$(basename "$target")"
}
