# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh"

# Interactive zsh config. .zshenv sources shell/common/exports.sh first (DOTFILES,
# env, PATH helpers); this file wires PATH, tools, oh-my-zsh, prompt, and sources
# the shared functions/aliases libraries.

# powerlevel10k instant prompt (keep at the top for speed)
[[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]] && source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"

# Fallback: if .zshenv was not loaded, derive DOTFILES and load exports.sh
# (defines path_prepend / path_append and the environment).
if [[ -z "${DOTFILES:-}" ]] || ! typeset -f path_prepend >/dev/null 2>&1; then
  DOTFILES="${${(%):-%x}:A:h:h:h}"
  export DOTFILES
  source "$DOTFILES/shell/common/exports.sh"
fi

# Canonical ANSI palette (FG_*/STYLE_*) the shell/common/* libraries render
# with. A pure leaf — colors only, no log()/confirm() verbs that would shadow
# system commands (e.g. the macOS `log` binary). See core/palette.sh, docs/INTERNALS.md.
source "$DOTFILES/core/palette.sh"

# -------------------------------------------------------- SHELL CONFIGURATION

# history settings
HISTSIZE=10000                # number of commands to remember
SAVEHIST=10000                # number of commands to save to history file
HISTFILE="$HOME/.zsh_history" # history file location
zshaddhistory() {
  local cmd="${1%%$'\n'}"
  [[ "$cmd" =~ ^(ls|ll|cd|pwd|exit|clear|history|c|whoami|hostname|ip|~|nano|cat|mkdir|ls\ -a|ls\ -la|ls\ -l|curl\ -I|docker\ ps|docker\ logs|docker-compose\ down|docker-compose\ up|rp)$ ]] && return 1
  return 0
}

# history options
setopt HIST_IGNORE_SPACE    # don't record commands starting with space
setopt HIST_REDUCE_BLANKS   # remove extra blanks from history
setopt HIST_IGNORE_ALL_DUPS # don't record duplicate commands
setopt HIST_SAVE_NO_DUPS    # don't write duplicate entries in history file
setopt HIST_FIND_NO_DUPS    # don't show duplicates when searching
setopt HIST_VERIFY          # verify before executing history commands
# setopt SHARE_HISTORY      # share history between all sessions
setopt HIST_NO_STORE        # don't record 'history' builtin commands themselves
setopt APPEND_HISTORY       # append to history file instead of overwriting
setopt INC_APPEND_HISTORY   # write to history file immediately, not when the shell exits

# directory navigation options
setopt AUTO_CD            # if command is a path, cd into it
setopt AUTO_PUSHD         # push the old directory onto the stack on cd
setopt PUSHD_IGNORE_DUPS  # do not store duplicates in the stack
setopt PUSHD_SILENT       # do not print directory stack after pushd/popd

# ----------------------------------------------------- CORE ENVIRONMENT SETUP

# homebrew env (must precede any brew-dependent PATH logic)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
: "${BREW_DIR:=$(brew --prefix 2>/dev/null)}"

# common flags - initialise if not set
[[ -z "$LDFLAGS" ]] && export LDFLAGS=""
[[ -z "$CPPFLAGS" ]] && export CPPFLAGS=""

# llvm (PATH + flags)
# path_prepend "$BREW_DIR/opt/llvm/bin"
# export LDFLAGS="$LDFLAGS -L$BREW_DIR/opt/llvm/lib"
# export CPPFLAGS="$CPPFLAGS -I$BREW_DIR/opt/llvm/include"

# openssl (PATH + flags)
# path_append "$BREW_DIR/opt/openssl@3/bin"
# export LDFLAGS="$LDFLAGS -L$BREW_DIR/opt/openssl@3/lib"
# export CPPFLAGS="$CPPFLAGS -I$BREW_DIR/opt/openssl@3/include"

# add homebrew to PATH
path_prepend "$BREW_DIR/bin"
path_prepend "$BREW_DIR/sbin"
export MANPATH="$BREW_DIR/share/man:$MANPATH"
export INFOPATH="$BREW_DIR/share/info:$INFOPATH"

# dotfiles CLI (dotfiles / dotf)
path_prepend "$DOTFILES/bin"

# personal CLI tools (ai_rename, ...)
path_prepend "$DOTFILES/tools"

# direnv for environment management
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# bat pager; lesspipe fallback when bat is not installed
if command -v bat >/dev/null 2>&1; then
    export LESSOPEN="| bat --paging=never %s"
    export LESS=" -R "
elif command -v lesspipe.sh >/dev/null 2>&1; then
    export LESSOPEN="|$(command -v lesspipe.sh) %s"
fi

# ---------------------------------------------------------- DEVELOPMENT TOOLS

# node and nvm (lazy-loaded via shell/common/nvm.sh)
# export NVM_DIR="${NVM_DIR:-$([ -n "$BREW_DIR" ] && [ -d "$BREW_DIR/opt/nvm" ] && echo "$BREW_DIR/opt/nvm" || echo "$HOME/.nvm")}"

# python and pyenv
export PYENV_ROOT="${PYENV_ROOT:-$([ -n "$BREW_DIR" ] && [ -d "$BREW_DIR/opt/pyenv" ] && echo "$BREW_DIR/opt/pyenv" || echo "$HOME/.pyenv")}"
if [[ -d "$PYENV_ROOT/bin" ]]; then
  path_prepend "$PYENV_ROOT/bin"
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
else
  printf '[warn] pyenv not found at %s\n' "$PYENV_ROOT" >&2
fi

# rbenv — uncomment when rbenv is in use on this machine
# if command -v rbenv >/dev/null 2>&1; then
#     eval "$(rbenv init - bash)"
# elif [[ -d "$HOME/.rbenv/bin" ]]; then
#     export PATH="$HOME/.rbenv/bin:$PATH"
#     eval "$(rbenv init - bash)"
# fi

# --------------------------------------------------------------------- PROMPT

# autosuggestions strategy (must be set before oh-my-zsh loads the plugin)
# history: most recent matching command | completion: fallback for paths/flags not in history
# async prevents completion's per-keypress latency from being a problem
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC=1

export ZSH=$HOME/.oh-my-zsh
ZSH_THEME="powerlevel10k/powerlevel10k" # set by `omz`
plugins=(
  git
  colored-man-pages
  # z                            # disabled: conflicts with zoxide (both define the z command)
  # fzf                          # disabled: conflicts with config/fzf/.fzf.sh source below (double keybinding registration)
  zsh-history-substring-search
  zsh-autosuggestions
  zsh-syntax-highlighting       # keeps the last position in the list to avoid conflicts with other plugins
  # python pip virtualenv
  # docker docker-compose kubectl
)
[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# -------------------------------------------------- COMPLETION AND NAVIGATION

# docker CLI completion
if [[ -d "$HOME/.docker/completions" ]]; then
  fpath=($fpath "$HOME/.docker/completions")
fi

# completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' # case insensitive tab completion
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"   # colored completion
zstyle ':completion:*' rehash true                        # automatically find new executables in path
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# history substring search keybinds
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# fzf integration (sourced from the repo, see config/fzf/.fzf.sh)
[[ -f "$DOTFILES/config/fzf/.fzf.sh" ]] && source "$DOTFILES/config/fzf/.fzf.sh"

# navigation tool zoxide
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# -------------------------------------------- CUSTOM SCRIPTS & CONFIGURATIONS

# source custom functions and aliases (direct $DOTFILES paths, symmetric with
# shell/bash/.bashrc; see docs/INTERNALS.md)
source "$DOTFILES/shell/common/functions.sh"
source "$DOTFILES/shell/common/aliases.sh"
source "$DOTFILES/shell/common/diag.sh"
source "$DOTFILES/shell/common/tool_loader.sh"

## eof

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"
