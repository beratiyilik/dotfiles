#!/usr/bin/env bash
# =============================================================================
# tool_loader.sh — source helper scripts on demand or via feature flags
#
# Manual (on-demand):
#   source_git_helpers
#   source_aws_helpers
#   ...
#
# Automatic (at shell startup):
#   Set DOTFILES_ENABLE_<TOOL>=true in env.sh or ~/.dotfiles.local
# =============================================================================

# lazy loading function for nvm
setup_nvm_lazy() {
  export NVM_DIR="${NVM_DIR:-$([ -n "$BREW_DIR" ] && [ -d "$BREW_DIR/opt/nvm" ] && echo "$BREW_DIR/opt/nvm" || echo "$HOME/.nvm")}"

  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    printf '[warn] nvm.sh not found at %s\n' "$NVM_DIR" >&2
    return 1
  fi

  _dispatch_nvm_command() {
    local command="$1"
    shift

    unset -f _dispatch_nvm_command
    unalias node npm nvm yarn npx pnpm 2>/dev/null || true

    # shellcheck disable=SC1090,SC1091
    source "$NVM_DIR/nvm.sh"

    # shellcheck disable=SC1090,SC1091
    [[ -s "$NVM_DIR/etc/bash_completion.d/nvm" ]] && source "$NVM_DIR/etc/bash_completion.d/nvm"
    # shellcheck disable=SC1090,SC1091
    [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

    if ! command -v "$command" &>/dev/null; then
      printf '[ERROR] Command "%s" not available after sourcing nvm\n' "$command" >&2
      return 127
    fi

    "$command" "$@"
  }

  for cmd in node npm nvm yarn npx pnpm; do
    alias "$cmd"="_dispatch_nvm_command $cmd"
  done
}

source_archive_helpers() {
    [[ -f "$DOTFILES_DIR/lib/archive_helpers.sh" ]] && source "$DOTFILES_DIR/lib/archive_helpers.sh"
}

source_git_helpers() {
    [[ -f "$DOTFILES_DIR/lib/git_helpers.sh" ]] && source "$DOTFILES_DIR/lib/git_helpers.sh"
}

source_aws_helpers() {
    [[ -f "$DOTFILES_DIR/lib/aws_helpers.sh" ]] && source "$DOTFILES_DIR/lib/aws_helpers.sh"
}

source_esp_idf_helpers() {
    [[ -f "$DOTFILES_DIR/lib/esp_idf_helpers.sh" ]] && source "$DOTFILES_DIR/lib/esp_idf_helpers.sh"
}

source_ai_rename() {
    local script="${AI_RENAME_PATH:-$DOTFILES_DIR/lib/ai_rename.sh}"
    [[ -f "$script" ]] && source "$script"
}

# =============================================================================
# Auto-load based on feature flags
# =============================================================================
[[ "${DOTFILES_ENABLE_NVM:-false}"             == "true" ]] && setup_nvm_lazy
[[ "${DOTFILES_ENABLE_ARCHIVE_HELPERS:-false}" == "true" ]] && source_archive_helpers
[[ "${DOTFILES_ENABLE_GIT_HELPERS:-false}"     == "true" ]] && source_git_helpers
[[ "${DOTFILES_ENABLE_AWS_HELPERS:-false}"     == "true" ]] && source_aws_helpers
[[ "${DOTFILES_ENABLE_ESP_IDF_HELPERS:-false}" == "true" ]] && source_esp_idf_helpers
[[ "${DOTFILES_ENABLE_AI_RENAME:-false}"       == "true" ]] && source_ai_rename
