#!/bin/bash

# ============================================================
# ENVIRONMENT CHECKS
# ============================================================

# if the shell is not interactive, do nothing.
[[ -z "$PS1" ]] && return

# ============================================================
# CORE ENVIRONMENT VARIABLES & PATH SETTINGS
# ============================================================

export LS_COLORS='ex=01;33:fi=00:di=01;34:ln=01;36:pi=40;33:so=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=01;05;37;41:'
export GREP_OPTIONS='--color=auto'
export GREP_COLOR='1;32'
export STARSHIP_SSH_IP=$(who am I | awk '{print $NF}' | tr -d '()')

# ============================================================
# CUSTOM ENVs, FUNCTIONS AND ALIASES
# ============================================================

[[ -f "$HOME/.bash_env" ]] && source "$HOME/.bash_env"
[[ -f "$HOME/.bash_functions" ]] && source "$HOME/.bash_functions"
[[ -f "$HOME/.bash_aliases" ]] && source "$HOME/.bash_aliases"

# ============================================================
# SHELL USABILITY SETTINGS
# ============================================================

# control how commands are stored and how duplicates/spaces are handled.
HISTCONTROL=ignoredups:ignorespace
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend  # append to history file, don't overwrite it.
# this ensures that the shell adjusts to the current size of the terminal
# upon each command, useful if you resize or attach via ssh or tmux.
shopt -s checkwinsize
# makes 'less' more friendly for non-text (e.g., compressed) files if available.
[[  -x /usr/bin/lesspipe ]] && eval "$(SHELL=/bin/sh lesspipe)"

# ============================================================
# PROMPT & VISUAL CUSTOMIZATIONS
# ============================================================

eval "$(starship init bash)"

# ============================================================
# DEVELOPMENT TOOLS, FRAMEWORKS, SDKs AND ENVIRONMENTS
# ============================================================

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

source /etc/profile.d/bash_completion.sh
source /usr/share/doc/fzf/examples/key-bindings.bash
eval "$(zoxide init bash)"

## eof
