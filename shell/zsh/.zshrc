# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh"

# powerlevel10k instant prompt (keep at the top for speed)
[[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]] && source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"

#############################################################################
# HELPER FUNCTIONS
#############################################################################

_prepend_to_path() { [[ -d "$1" && ":$PATH:" != *":$1:"* ]] && export PATH="$1:$PATH"; }
_append_to_path() { [[ -d "$1" && ":$PATH:" != *":$1:"* ]] && export PATH="$PATH:$1"; }

#############################################################################
# SHELL CONFIGURATION
#############################################################################

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
setopt HIST_NO_STORE        # don't record 'history' builtin commands themselves (not: "commands not executed")
setopt APPEND_HISTORY       # append to history file instead of overwriting
setopt INC_APPEND_HISTORY   # write to history file immediately, not when the shell exits

# directory navigation options
setopt AUTO_CD            # if command is a path, cd into it
setopt AUTO_PUSHD         # push the old directory onto the stack on cd
setopt PUSHD_IGNORE_DUPS  # do not store duplicates in the stack
setopt PUSHD_SILENT       # do not print directory stack after pushd/popd

#############################################################################
# CORE ENVIRONMENT SETUP
#############################################################################

# homebrew env (must precede any brew-dependent PATH logic)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
: "${BREW_DIR:=$(brew --prefix 2>/dev/null)}"

# common flags – initialise if not set
[[ -z "$LDFLAGS" ]] && export LDFLAGS=""
[[ -z "$CPPFLAGS" ]] && export CPPFLAGS=""

# llvm (PATH + flags)
# _prepend_to_path "$BREW_DIR/opt/llvm/bin"
# export LDFLAGS="$LDFLAGS -L$BREW_DIR/opt/llvm/lib"
# export CPPFLAGS="$CPPFLAGS -I$BREW_DIR/opt/llvm/include"

# openssl (PATH + flags)
# _append_to_path "$BREW_DIR/opt/openssl@3/bin"
# export LDFLAGS="$LDFLAGS -L$BREW_DIR/opt/openssl@3/lib"
# export CPPFLAGS="$CPPFLAGS -I$BREW_DIR/opt/openssl@3/include"

# add homebrew to PATH
_prepend_to_path "$BREW_DIR/bin"
_prepend_to_path "$BREW_DIR/sbin"
export MANPATH="$BREW_DIR/share/man:$MANPATH"
export INFOPATH="$BREW_DIR/share/info:$INFOPATH"

# dotfiles CLI
_append_to_path "${DOTFILES_DIR:-$HOME/dotfiles}"

# direnv for environment management
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# bat (syntax-highlighted pager)
export LESSOPEN="| bat --paging=never %s"
export LESS=" -R "

#############################################################################
# DEVELOPMENT TOOLS
#############################################################################

# python and pyenv
export PYENV_ROOT="${PYENV_ROOT:-$([ -n "$BREW_DIR" ] && [ -d "$BREW_DIR/opt/pyenv" ] && echo "$BREW_DIR/opt/pyenv" || echo "$HOME/.pyenv")}"
if [[ -d "$PYENV_ROOT/bin" ]]; then
  _prepend_to_path "$PYENV_ROOT/bin"
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
else
  printf '[warn] pyenv not found at %s\n' "$PYENV_ROOT" >&2
fi

# ruby
# _append_to_path "$BREW_DIR/opt/ruby/bin"
# rbenv
# _rbenv_bin="${BREW_DIR:+$([ -d "$BREW_DIR/opt/rbenv/bin" ] && echo "$BREW_DIR/opt/rbenv/bin")}"
# _rbenv_bin="${_rbenv_bin:-$HOME/.rbenv/bin}"
# if [[ -d "$_rbenv_bin" ]]; then
#   _prepend_to_path "$_rbenv_bin"
#   eval "$(rbenv init -)"
# else
#   printf '[warn] rbenv not found at %s\n' "$_rbenv_bin" >&2
# fi
# unset _rbenv_bin

# cmake
# _append_to_path "$BREW_DIR/opt/cmake/bin"

# dotnet
# export DOTNET_ROOT="$BREW_DIR/opt/dotnet-sdk"
# _append_to_path "$HOME/.dotnet/tools"

# pnpm
# export PNPM_HOME="$HOME/Library/pnpm"
# _prepend_to_path "$PNPM_HOME/bin"

#############################################################################
# APPLICATIONS & UTILITIES
#############################################################################

# docker
# export PATH="$BREW_DIR/opt/docker/bin:$PATH"
# _append_to_path "/Applications/Docker.app/Contents/Resources/bin"

# code (VSCode)
# _append_to_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

# wireshark and tshark
# export PATH="$BREW_DIR/opt/wireshark/bin:$PATH"
# _append_to_path "/Applications/Wireshark.app/Contents/MacOS"
# sudo ln -s /Applications/Wireshark.app/Contents/MacOS/Wireshark /usr/local/bin/wireshark
# sudo ln -s /Applications/Wireshark.app/Contents/MacOS/tshark /usr/local/bin/tshark

# azure data studio
# _append_to_path "/Applications/Azure Data Studio.app/Contents/Resources/app/bin"

# coteditor
# _append_to_path "/Applications/CotEditor.app/Contents/SharedSupport/bin"

# autosuggestions strategy (must be set before oh-my-zsh loads the plugin)
# ZSH_AUTOSUGGEST_STRATEGY=(history completion)  # completion strategy queries the completion engine on every keypress, can slow terminal
ZSH_AUTOSUGGEST_STRATEGY=(history)

#############################################################################
# OH-MY-ZSH, PLUGINS AND CONFIGURATIONS
#############################################################################

export ZSH=$HOME/.oh-my-zsh
ZSH_THEME="powerlevel10k/powerlevel10k" # set by `omz`
plugins=(
  git
  colored-man-pages
  # z                            # disabled: conflicts with zoxide (both define the z command)
  # fzf                          # disabled: conflicts with ~/.fzf.sh source below (double keybinding registration)
  zsh-history-substring-search
  zsh-autosuggestions
  zsh-syntax-highlighting       # keeps the last position in the list to avoid conflicts with other plugins
  # python pip virtualenv
  # docker docker-compose kubectl
)
[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

#############################################################################
# COMPLETION AND NAVIGATION
#############################################################################

# cocker CLI completion
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

# fzf integration
[[ -f "$HOME/.fzf.sh" ]] && source "$HOME/.fzf.sh"

# navigation tool zoxide
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

#############################################################################
# CUSTOM SCRIPTS & CONFIGURATIONS
#############################################################################

# source custom functions and aliases
[[ -f "$SHELL_FUNCTIONS_PATH" ]] && source "$SHELL_FUNCTIONS_PATH"
[[ -f "$SHELL_ALIASES_PATH" ]] && source "$SHELL_ALIASES_PATH"

# log library
if [[ -f "$DOTFILES_DIR/lib/log.sh" ]] && [[ -z "${LOG_SH_INCLUDED:-}" ]]; then
  source "$DOTFILES_DIR/lib/log.sh"
fi

# tool loader — sources helpers based on DOTFILES_ENABLE_* flags in env.sh / ~/.dotfiles.local
# call source_<tool> manually at any time to load on demand (e.g. source_aws_helpers)
[[ -f "$DOTFILES_DIR/lib/tool_loader.sh" ]] && source "$DOTFILES_DIR/lib/tool_loader.sh"

## eof

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"
