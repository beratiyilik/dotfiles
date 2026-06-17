# shellcheck shell=bash
# Sourced by .zshrc and .bashrc (interactive shells only — not exports.sh).
# Conditionally loads optional helpers based on DOTFILES_ENABLE_* feature flags
# defined in vars/common.env (defaults) and overridden in vars/local.env.
[[ -n "${__DF_TOOL_LOADER_LOADED:-}" ]] && return 0
readonly __DF_TOOL_LOADER_LOADED=1

: "${DOTFILES:?DOTFILES not set — source exports.sh first}"

[[ "${DOTFILES_ENABLE_NVM:-false}"             == "true" ]] && source "$DOTFILES/shell/common/nvm.sh"
[[ "${DOTFILES_ENABLE_GIT_HELPERS:-false}"     == "true" ]] && source "$DOTFILES/shell/common/git.sh"
[[ "${DOTFILES_ENABLE_AWS_HELPERS:-false}"     == "true" ]] && source "$DOTFILES/shell/common/aws.sh"
[[ "${DOTFILES_ENABLE_ESP_IDF_HELPERS:-false}" == "true" ]] && source "$DOTFILES/shell/common/esp.sh"
