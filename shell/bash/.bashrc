# shellcheck shell=bash
# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/bashrc.pre.bash" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/bashrc.pre.bash"

# if not running interactively, don't do anything! keep this check at the top
[[ -z "$PS1" ]] && return

# Bootstrap: detect DOTFILES_DIR from .bashrc's real path by resolving the symlink.
# .bashrc lives at shell/bash/.bashrc — two levels below the repo root.
# macOS readlink (without -f) is sufficient because dotfiles init creates absolute symlinks.
if [ -z "${DOTFILES_DIR:-}" ]; then
  _rc_real="$(readlink "${BASH_SOURCE[0]}" 2>/dev/null)"
  if [ -n "$_rc_real" ]; then
    DOTFILES_DIR="$(cd "$(dirname "$_rc_real")/../.." 2>/dev/null && pwd)"
  fi
  : "${DOTFILES_DIR:=$HOME/dotfiles}"
  unset _rc_real
fi
export DOTFILES_DIR
SHELL_ENV_PATH="$DOTFILES_DIR/lib/env.sh"
[[ -f "$SHELL_ENV_PATH" ]] && source "$SHELL_ENV_PATH"

#############################################################################
# HELPER FUNCTIONS
#############################################################################

_prepend_to_path() { [[ -d "$1" && ":$PATH:" != *":$1:"* ]] && export PATH="$1:$PATH"; }
_append_to_path() { [[ -d "$1" && ":$PATH:" != *":$1:"* ]] && export PATH="$PATH:$1"; }

#############################################################################
# SHELL CONFIGURATION
#############################################################################

# history settings – tuned for bash 5
HISTSIZE=10000                   # larger history size
HISTFILESIZE=100000              # much larger history file
HISTFILE="$HOME/.bash_history"   # history file location
HISTCONTROL=ignoreboth:erasedups # ignoredups + ignorespace + erase duplicates
HISTIGNORE="ls:ll:cd:pwd:exit:clear:history:c:whoami:hostname:ip:~:nano:cat:ls -a:ls -la:ls -l:mkdir:curl -I *:docker ps*:docker logs*:docker-compose down*:docker-compose up*:rp"
HISTTIMEFORMAT="%F %T " # add timestamps to history

# macOS and bash 5 specific shell options
shopt -s histappend           # append to history file, don't overwrite
shopt -s checkwinsize         # update window size after each command
shopt -s globstar 2>/dev/null # enable ** for recursive matches (bash 4+)
shopt -s autocd 2>/dev/null   # type directory name to cd into it (bash 4+)
shopt -s dirspell 2>/dev/null # correct minor spelling errors in cd commands
shopt -s cdspell              # correct minor spelling errors in cd commands

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
_append_to_path "$DOTFILES_DIR"

# direnv – environment manager (placed here, close to core env logic)
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"

# pager configuration – prefer bat, fallback to lesspipe
if command -v bat &>/dev/null; then
    export LESSOPEN="| bat --paging=never %s"
    export LESS=" -R "
else
    if [[ -x "/usr/bin/lesspipe.sh" ]]; then
        export LESSOPEN="|/usr/bin/lesspipe.sh %s"
    elif [[ -x "$BREW_DIR/bin/lesspipe.sh" ]]; then
        export LESSOPEN="|$BREW_DIR/bin/lesspipe.sh %s"
    fi
fi

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

# ruby and rbenv
# _append_to_path "$BREW_DIR/opt/ruby/bin"
_rbenv_bin="${BREW_DIR:+$([ -d "$BREW_DIR/opt/rbenv/bin" ] && echo "$BREW_DIR/opt/rbenv/bin")}"
_rbenv_bin="${_rbenv_bin:-$HOME/.rbenv/bin}"
if [[ -d "$_rbenv_bin" ]]; then
  _prepend_to_path "$_rbenv_bin"
  eval "$(rbenv init -)"
else
  printf '[warn] rbenv not found at %s\n' "$_rbenv_bin" >&2
fi
unset _rbenv_bin

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

# code (vscode)
# _append_to_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

# cursor
# _append_to_path "/Applications/Cursor.app/Contents/Resources/app/bin"

# wireshark and tshark
# export PATH="$BREW_DIR/opt/wireshark/bin:$PATH"
# _append_to_path "/Applications/Wireshark.app/Contents/MacOS"
# sudo ln -s /Applications/Wireshark.app/Contents/MacOS/Wireshark /usr/local/bin/wireshark
# sudo ln -s /Applications/Wireshark.app/Contents/MacOS/tshark /usr/local/bin/tshark

# azure data studio
# _append_to_path "/Applications/Azure Data Studio.app/Contents/Resources/app/bin"

# coteditor
# _append_to_path "/Applications/CotEditor.app/Contents/SharedSupport/bin"

#############################################################################
# PROMPT CONFIGURATION
#############################################################################

# load bashify prompt – leave in place for clarity
BASHIFY_PATH="${HOME}/dotfiles/scripts/bash/bashify.bash"
[[ -f "$BASHIFY_PATH" ]] && source "$BASHIFY_PATH"

#############################################################################
# COMPLETION AND NAVIGATION
#############################################################################

# git prompt
GIT_PS1_SHOWDIRTYSTATE=true
GIT_PS1_SHOWSTASHSTATE=true
GIT_PS1_SHOWUNTRACKEDFILES=true
GIT_PS1_SHOWUPSTREAM="auto"
GIT_PS1_HIDE_IF_PWD_IGNORED=true
GIT_PS1_SHOWCOLORHINTS=true
# source git-prompt if it exists (for bashify to use)
[[ -f "$BREW_DIR/etc/bash_completion.d/git-prompt.sh" ]] && source "$BREW_DIR/etc/bash_completion.d/git-prompt.sh"

# completion
# bash-completion (must load before per-tool completions)
if [[ -f "$BREW_DIR/etc/bash_completion" ]]; then
    source "$BREW_DIR/etc/bash_completion"
elif [[ -f "$BREW_DIR/share/bash-completion/bash_completion" ]]; then
    source "$BREW_DIR/share/bash-completion/bash_completion"
fi

# cocker CLI completion
[[ -f "$HOME/.docker/completions/docker" ]] && source "$HOME/.docker/completions/docker"

# SSH hostnames from ~/.ssh/config
[[ -f "$HOME/.ssh/config" ]] && complete -o "default" -o "nospace" \
    -W "$(grep "^Host" ~/.ssh/config | grep -v "[?*]" | cut -d " " -f2- | tr ' ' '\n')" \
    scp sftp ssh

# fzf integration
[[ -f "$HOME/.fzf.sh" ]] && source "$HOME/.fzf.sh"

# navigation tool zoxide
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"

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
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/bashrc.post.bash" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/bashrc.post.bash"
