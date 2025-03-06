#!/bin/bash

# ============================================================
# ENVIRONMENT CHECKS
# ============================================================

# if the shell is not interactive, do nothing.
[[ -z "$PS1" ]] && return
# checks if we are in a debian chroot and, if so, sets a helpful variable.
if [[  -z "$debian_chroot" ]] && [[ -r /etc/debian_chroot ]]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# ============================================================
# CORE ENVIRONMENT VARIABLES & PATH SETTINGS
# ============================================================
# (no variables explicitly set here in original)

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

# enable colored prompt if the terminal supports it
case "$TERM" in
  xterm-color) color_prompt=yes ;;
esac
# allow forcing color prompt
if [[ -n "$force_color_prompt" ]]; then
  if [[ -x /usr/bin/tput ]] && tput setaf 1 >&/dev/null; then
    color_prompt=yes
  else
    color_prompt=
  fi
fi
# define the prompt based on color support
if [[ "$color_prompt" == "yes" ]]; then
  PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
  PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
# unset temporary variables
unset color_prompt force_color_prompt
# set the title bar of xterm or rxvt terminals
case "$TERM" in
  xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
esac
# enable color support for ls and grep if dircolors exists
if [[ -x /usr/bin/dircolors ]]; then
    if [[ -r ~/.dircolors ]]; then
        eval "$(dircolors -b ~/.dircolors)"
    else
        eval "$(dircolors -b)"
    fi

    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi
#
COLOR_USERNAME="\[\033[01;32m\]"
COLOR_HOSTNAME="\[\033[0m\]"
COLOR_PATH="\[\033[01;34m\]"
if [[ -z "$IP" ]]; then
    export IP=$(curl -s ifconfig.me)
fi
PS1="${COLOR_USERNAME}\u${COLOR_HOSTNAME}@${IP} ${COLOR_PATH}\W \$ "

# ============================================================
# DEVELOPMENT TOOLS, FRAMEWORKS, SDKs AND ENVIRONMENTS
# ============================================================
# (no specific tool/application configs in original aside from sources above)

## eof
