#!/usr/bin/env bash
# Source-only library (see docs/INTERNALS.md). Idempotent.
# Single source of truth for backup/snapshot output location and timestamp format.
[[ -n "${__DF_PATHS_LOADED:-}" ]] && return 0
readonly __DF_PATHS_LOADED=1

# $DOTFILES is derived+exported at the entry point (see docs/INTERNALS.md);
# libraries only ever trust it.
: "${DOTFILES:?DOTFILES not set — derive it at the entry point (see docs/INTERNALS.md)}"

# All backup and snapshot output lives under one gitignored root. Honored from
# the environment if already set (handy for isolated tests / redirecting output);
# otherwise derived from the repo root.
DF_BACKUPS_ROOT="${DF_BACKUPS_ROOT:-$DOTFILES/backups}"
DF_BACKUP_TS_FORMAT="%Y%m%d_%H%M%S"

# df_backup_stamp → "<timestamp>_<pid>", the per-run identifier.
df_backup_stamp() {
    printf '%s_%s' "$(date +"$DF_BACKUP_TS_FORMAT")" "$$"
}

# df_backup_dir <kind> <stamp> [base] → "<base|DF_BACKUPS_ROOT>/<kind>_<stamp>"
# Single source of truth for output directory naming. Output lives flat under
# one root with a type prefix (backup_…, snapshot_…) that mirrors the command
# name — no per-type subdirectories. Callers pass their own <stamp> so the same
# value can be reused elsewhere (e.g. a summary header) without re-deriving it.
df_backup_dir() {
    local kind="$1" stamp="$2" base="${3:-$DF_BACKUPS_ROOT}"
    printf '%s/%s_%s' "$base" "$kind" "$stamp"
}
