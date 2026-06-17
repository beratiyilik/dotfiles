#!/usr/bin/env bash
# Sourced BEFORE init (before symlink + OS setup) by `dotfiles init`
# (bin/dotfiles → cmd_init). Runs under `set -euo pipefail` in the same shell,
# so the log_* helpers from core/utils.sh and the detected $OS are available.
# Keep every step idempotent and fault-tolerant so re-running `dotfiles init`
# is always safe.

# --- Homebrew (macOS only, idempotent) ---
# macOS package setup (config/homebrew/Brewfile via `dotfiles os`) needs brew.
# Install only when missing; a second `init` is a no-op. A failed install warns
# but does not abort init — the rest of the setup degrades gracefully.
if is_macos; then
    if has_cmd brew; then
        log_info "Homebrew already installed — skipping."
    else
        log_info "Homebrew not found — installing (NONINTERACTIVE)…"
        # `if … then/else` keeps set -e from aborting init on a failed install.
        if NONINTERACTIVE=1 /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            log_ok "Homebrew installed."
        else
            log_warn "Homebrew install failed — continuing without it (retry later with 'dotfiles os')."
        fi
    fi

    # Make a freshly installed brew usable for the rest of this run. Mirrors the
    # prefix detection in shell/common/exports.sh (Apple Silicon vs Intel). An
    # if/elif with no else exits 0, so this is safe under set -e.
    if ! has_cmd brew; then
        if [[ -x /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
fi
