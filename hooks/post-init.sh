#!/usr/bin/env bash
# Sourced AFTER init (after symlink + OS setup) by `dotfiles init`
# (bin/dotfiles → cmd_init). Runs under `set -euo pipefail` in the same shell,
# so the log_* helpers from core/utils.sh are available. Steps here depend on the
# now-linked config (e.g. ~/.zshrc expecting oh-my-zsh + powerlevel10k). Keep every
# step idempotent and fault-tolerant so re-running `dotfiles init` is always safe.

# --- oh-my-zsh + plugins + powerlevel10k (idempotent) ---
# Installs into ~/.oh-my-zsh as expected by shell/zsh/.zshrc:
#   ZSH_THEME="powerlevel10k/powerlevel10k"
#   plugins=(... zsh-history-substring-search zsh-autosuggestions zsh-syntax-highlighting)
if has_cmd git; then
    ZSH="${ZSH:-$HOME/.oh-my-zsh}"
    ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

    # oh-my-zsh core (keep our symlinked ~/.zshrc; don't switch shell or run zsh)
    if [[ ! -d "$ZSH" ]] && has_cmd curl; then
        log_info "Installing oh-my-zsh…"
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
            || log_warn "oh-my-zsh install failed — skipping theme/plugins."
    fi

    if [[ -d "$ZSH" ]]; then
        # "$ZSH_CUSTOM-relative dest  repo" — clone_if_missing handles the skip /
        # log / fault-tolerant clone. Add a plugin = one line in the heredoc.
        while read -r dest repo; do
            [[ -z "$dest" ]] && continue
            clone_if_missing "$ZSH_CUSTOM/$dest" "$repo"
        done <<'EOF'
themes/powerlevel10k https://github.com/romkatv/powerlevel10k.git
plugins/zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
plugins/zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
plugins/zsh-history-substring-search https://github.com/zsh-users/zsh-history-substring-search
EOF
        log_ok "zsh framework ready."
    fi
fi

# --- bashify prompt (idempotent) ---
# bashify is a standalone project (github.com/beratiyilik/bashify), installed to
# ~/.bashify and sourced by shell/bash/.bashrc. We pin RC_FILE=/dev/null so the
# installer does NOT append its own source line to our symlinked ~/.bashrc (we
# source it ourselves). The ~/.config/bashify/bashifyrc config is already linked by
# `dotfiles link` (runs before this hook), so the installer won't overwrite it.
# The installer is fetched from HEAD (the default branch tip) so the one-liner keeps
# working if bashify renames its default branch; bashify itself then resolves the
# latest release tag. Its stdout is silenced (it would otherwise print confusing
# "Installed bashify into /dev/null" lines) while stderr is kept for real errors.
BASHIFY_DIR="${BASHIFY_DIR:-$HOME/.bashify}"
if [[ ! -f "$BASHIFY_DIR/bashify.bash" ]] && has_cmd curl; then
    log_info "Installing bashify…"
    BASHIFY_DIR="$BASHIFY_DIR" RC_FILE=/dev/null \
        bash -c "$(curl -fsSL https://raw.githubusercontent.com/beratiyilik/bashify/HEAD/install.sh)" >/dev/null \
        || log_warn "bashify install failed — bash prompt will fall back to default."
fi
[[ -f "$BASHIFY_DIR/bashify.bash" ]] && log_ok "bashify ready."
