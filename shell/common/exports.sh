# shellcheck shell=bash
# Sourced by .zshenv (zsh) and .bashrc (bash). Defines DOTFILES, environment,
# workspace paths, tool config, date formats, feature flags, and PATH helpers.
# Ported from the legacy lib/env.sh; standardized on $DOTFILES.

# ---------------------------------------------- DOTFILES ROOT (self-locating)
# Honored if already set (by .zshenv / .bashrc / bin/dotfiles); otherwise
# derived from this file's real location. The zsh-only expansion is kept inside
# eval so bash (which also sources this file) never has to parse it.
if [ -z "${DOTFILES:-}" ]; then
  if [ -n "${ZSH_VERSION:-}" ]; then
    eval '_df_src="${(%):-%x}"'
  else
    _df_src="${BASH_SOURCE[0]:-$0}"
  fi
  DOTFILES="$(cd "$(dirname "$_df_src")/../.." 2>/dev/null && pwd)"
  unset _df_src
fi
export DOTFILES

# ---------------------------- PATH HELPERS (idempotent; shared by zsh + bash)

# prepend $1 to PATH if it is a directory and not already present
path_prepend() { [ -d "$1" ] && case ":$PATH:" in *":$1:"*) ;; *) export PATH="$1:$PATH" ;; esac; }
# append $1 to PATH if it is a directory and not already present
path_append()  { [ -d "$1" ] && case ":$PATH:" in *":$1:"*) ;; *) export PATH="$PATH:$1" ;; esac; }

# ----------------------------------------------------------- USER INFORMATION

export USER_USERNAME="beratiyilik"
export USER_FULLNAME="Berat Iyilik"
export USER_EMAIL=""

# --------------------------------------------------------- PATH CONFIGURATION

# export PATH="$HOME/.local/bin:$PATH"
# export PATH="$HOME/.npm-global/bin:$PATH"
# export PATH="$HOME/.cargo/bin:$PATH"
# export GOPATH="$HOME/go"
# export PATH="$GOPATH/bin:$PATH"

# -------------------------------------------- WORKSPACE & DIRECTORY STRUCTURE

export REPOS="repos"
export REPOS_DIR="$HOME/$REPOS"
export LOG_DIR="$HOME/Library/Logs/MyScripts"
export CACHE_DIR="$HOME/Library/Caches/MyScripts"
export APP_SUPPORT_DIR="$HOME/Library/Application Support/MyScripts"
export TEMP_DIR="${TMPDIR:-/tmp}/${USER}"

# -------------------------------------------------------- SHELL CONFIGURATION

# unified function/alias libraries live under shell/common (Bash + Zsh)
export SHELL_FUNCTIONS="functions.sh"
export SHELL_ALIASES="aliases.sh"
export SHELL_FUNCTIONS_PATH="$DOTFILES/shell/common/$SHELL_FUNCTIONS"
export SHELL_ALIASES_PATH="$DOTFILES/shell/common/$SHELL_ALIASES"

# shell-specific file names and paths
if [ -n "${ZSH_VERSION:-}" ]; then
  export SHELL_RC=".zshrc"
  export SHELL_PROFILE=".zprofile"
  export SHELL_ENV=".zshenv"
  export SHELL_ENV_PATH="$HOME/$SHELL_ENV"
elif [ -n "${BASH_VERSION:-}" ]; then
  export SHELL_RC=".bashrc"
  export SHELL_PROFILE=".bash_profile"
  export SHELL_ENV="exports.sh"
  export SHELL_ENV_PATH="$DOTFILES/shell/common/$SHELL_ENV"
fi

export SHELL_RC_PATH="$HOME/$SHELL_RC"
export SHELL_PROFILE_PATH="$HOME/$SHELL_PROFILE"

# --------------------------------------------------------------------- LOCALE

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# -------------------------------------------- DEVELOPMENT TOOLS CONFIGURATION

# editor
# EDITOR: used by git and other CLI tools for non-visual editing (e.g. commit messages, rebase)
export EDITOR="nano"
# VISUAL: preferred full-screen editor; set to same as EDITOR to prevent GUI editor fallback
export VISUAL="nano"

# color output (bash-specific, harmless in zsh)
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad

# homebrew
if [ -x /opt/homebrew/bin/brew ]; then
  export BREW_DIR="/opt/homebrew"   # Apple Silicon
elif [ -x /usr/local/bin/brew ]; then
  export BREW_DIR="/usr/local"      # Intel Mac
else
  export BREW_DIR=""
fi

# git
export GITCONFIG_PATH="$HOME/.gitconfig"
export GITHUB_HOSTNAME="https://github.com/"
export GITHUB_GIST_HOSTNAME="https://gist.github.com/"
export GITHUB_GIST_GITHUBUSERCONTENT_HOSTNAME="https://gist.githubusercontent.com/"
export GITHUB_PERSONAL_ACCESS_TOKEN=""

# npm
export NPM_ACCESS_TOKEN=""

# ssh
export SSH_CONFIG_PATH="$HOME/.ssh/config"

# 1password ssh agent configuration
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# claude
export CLAUDE_API_KEY=""

# -------------------------------------------------------- DATE & TIME FORMATS

export LONG_DATETIME_FORMAT="%a %b %d %Y %H:%M:%S %I:%M %p %Z" # Sun Jul 04 2021 14:30:00 02:30 PM +03
export SHORT_DATE_FORMAT="%a %b %d %Y"                          # Sun Jul 04 2021
export DATE_SUFFIX_FORMAT="%Y%m%d"                              # YYYYMMDD
export TIME_SUFFIX_FORMAT="%H%M%S"                              # HHMMSS
export DATETIME_SUFFIX_FORMAT="%Y%m%d%H%M%S"                    # YYYYMMDDHHMMSS
export LOG_TIMESTAMP_FORMAT="%Y-%m-%dT%H:%M:%SZ"                # 2021-07-04T14:30:00Z

# --------------------------------- TEMPLATE / MANIFEST VARIABLES (vars/*.env)
# Loaded into the shell environment AND consumed by core/py/template.py.
# Format: KEY=value (no 'export', no shell expansion). local.env overrides common.env.
__load_env() {
  [ -f "$1" ] || return 0
  set -a
  # shellcheck source=/dev/null
  . "$1"
  set +a
}
__load_env "$DOTFILES/vars/common.env"
__load_env "$DOTFILES/vars/local.env"
unset -f __load_env

# -------------------------------------------------------------- FEATURE FLAGS
# Consumed by shell/common/tool_loader.sh (sourced by .zshrc / .bashrc).
# Override any of these in vars/local.env without modifying this file.

export DOTFILES_ENABLE_NVM=true
export DOTFILES_ENABLE_GIT_HELPERS=true
export DOTFILES_ENABLE_AWS_HELPERS=false
export DOTFILES_ENABLE_ESP_IDF_HELPERS=false

## eof
