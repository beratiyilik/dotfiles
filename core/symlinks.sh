#!/usr/bin/env bash
# Source-only library (see docs/INTERNALS.md). Idempotent.
[[ -n "${__DF_SYMLINKS_LOADED:-}" ]] && return 0
readonly __DF_SYMLINKS_LOADED=1

: "${DOTFILES:?DOTFILES not set — run via bin/dotfiles}"
source "$DOTFILES/core/utils.sh"    # idempotent (self-guarded)
source "$DOTFILES/core/backup.sh"   # idempotent (self-guarded)

link_all() {
    local manifest="$DOTFILES/.symlinks"
    # PYTHON is detected once by bin/dotfiles and exported; reuse it (empty when
    # python3 is absent → template entries are skipped with a warning below).
    local python="${PYTHON:-}"

    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line"     ]] && continue

        local src target flags
        src=$(echo "$line"    | awk '{print $1}')
        target=$(echo "$line" | awk '{print $3}')
        flags=$(echo "$line"  | awk '{print $4}')

        target="${target/#\~/$HOME}"

        if [[ "$flags" == "[template]" ]]; then
            if [[ -z "$python" ]]; then
                log_error "python3 not found, skipping template: $src"
                continue
            fi
            "$python" "$DOTFILES/core/py/template.py" \
                "$DOTFILES/$src" "$target"
            continue
        fi

        backup_file "$target"
        mkdir -p "$(dirname "$target")"

        if ln -sf "$DOTFILES/$src" "$target"; then
            log_ok "Linked: $src → $target"
        else
            log_error "Link failed: $src → $target"
        fi

    done < "$manifest"
}
