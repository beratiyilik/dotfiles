# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/bashrc.pre.bash" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/bashrc.pre.bash"

# shellcheck shell=bash
# bash has NO equivalent of .zshenv. DOTFILES + environment + interactive config go here.
# .bash_profile (login) sources this file.
# Resolves the symlink chain and goes two levels up to find the repo root.
if [[ -z "${DOTFILES:-}" ]]; then
    __src="${BASH_SOURCE[0]}"
    while [[ -L "$__src" ]]; do
        __dir="$(cd -P "$(dirname "$__src")" && pwd)"
        __src="$(readlink "$__src")"
        [[ "$__src" != /* ]] && __src="$__dir/$__src"
    done
    DOTFILES="$(cd -P "$(dirname "$__src")/../.." && pwd)"
    unset __src __dir
fi
export DOTFILES
# shellcheck source=/dev/null
source "$DOTFILES/shell/common/exports.sh"

# -------------------------------------------------------- SHELL CONFIGURATION

HISTFILE="$HOME/.bash_history"
HISTSIZE=10000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%F %T "
HISTIGNORE="ls:ll:cd:pwd:exit:clear:history:c:whoami:hostname:~:nano:cat:mkdir:ls -a:ls -la:ls -l:curl -I *:docker ps*:docker logs*:rp"
shopt -s histappend

shopt -s checkwinsize         # update LINES/COLUMNS after each command
shopt -s cdspell  2>/dev/null # correct minor typos in cd arguments
shopt -s dirspell 2>/dev/null # correct directory names during tab completion
shopt -s globstar 2>/dev/null # enable ** glob for recursive matches (bash 4+)
shopt -s autocd   2>/dev/null # type a dir name to cd into it (bash 4+)

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
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"

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

# bashify is a standalone project (github.com/beratiyilik/bashify) installed to
# ~/.bashify by hooks/post-init.sh; we source it from there instead of vendoring it.
# shellcheck source=/dev/null
[[ -f "${BASHIFY_DIR:-$HOME/.bashify}/bashify.bash" ]] \
    && source "${BASHIFY_DIR:-$HOME/.bashify}/bashify.bash"

# -------------------------------------------------- COMPLETION AND NAVIGATION

if ! shopt -oq posix; then
    # shellcheck source=/dev/null
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        source /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        # shellcheck source=/dev/null
        source /etc/bash_completion
    elif [[ -n "${HOMEBREW_PREFIX:-}" && -f "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh" ]]; then
        # shellcheck source=/dev/null
        source "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh"
    fi
fi

# SSH host completion from ~/.ssh/config
if [[ -f "$HOME/.ssh/config" ]]; then
    _ssh_hosts=$(grep "^Host" "$HOME/.ssh/config" 2>/dev/null \
        | grep -v "[?*]" | cut -d " " -f2- | tr ' ' '\n')
    complete -o "default" -o "nospace" -W "$_ssh_hosts" scp sftp ssh
    unset _ssh_hosts
fi

# docker CLI completion
# shellcheck source=/dev/null
[[ -f "$HOME/.docker/completions/docker" ]] && source "$HOME/.docker/completions/docker"

# fzf integration (sourced from the repo, see config/fzf/.fzf.sh)
[[ -f "$DOTFILES/config/fzf/.fzf.sh" ]] && source "$DOTFILES/config/fzf/.fzf.sh"

# navigation tool zoxide
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"

# -------------------------------------------- CUSTOM SCRIPTS & CONFIGURATIONS

# shellcheck source=/dev/null
source "$DOTFILES/shell/common/functions.sh"
# shellcheck source=/dev/null
source "$DOTFILES/shell/common/aliases.sh"
# shellcheck source=/dev/null
source "$DOTFILES/shell/common/diag.sh"
# shellcheck source=/dev/null
source "$DOTFILES/shell/common/tool_loader.sh"

## eof

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/bashrc.post.bash" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/bashrc.post.bash"
