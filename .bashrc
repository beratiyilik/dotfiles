#!/bin/bash

# curl -s {GITHUB_PATH} > ~/.bashrc

# ============================================================
# ENVIRONMENT CHECKS
# ============================================================
# if the shell is not interactive, do nothing.
[ -z "$PS1" ] && return
# checks if we are in a debian chroot and, if so, sets a helpful variable.
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# ============================================================
# CORE ENVIRONMENT VARIABLES
# ============================================================
# (no variables explicitly set here in original)

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
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ============================================================
# CUSTOM ENVs, FUNCTIONS AND ALIASES
# ============================================================
# load custom zsh env declarations
[ -f "$HOME/.bash_env" ] && . "$HOME/.bash_env"
# load custom zsh function definitions
[ -f "$HOME/.bash_functions" ] && . "$HOME/.bash_functions"
# load custom zsh aliases
[ -f "$HOME/.bash_aliases" ] && . "$HOME/.bash_aliases"

# ============================================================
# TOOL AND APPLICATION CONFIGURATIONS
# ============================================================
# (no specific tool/application configs in original aside from sources above)

# ============================================================
# PROMPT & VISUAL CUSTOMIZATIONS
# ============================================================
# depending on terminal capabilities, switch on/off color prompts.
case "$TERM" in
  xterm-color) color_prompt=yes;;
esac

if [ -n "$force_color_prompt" ]; then
  if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    color_prompt=yes
  else
    color_prompt=
  fi
fi
# if colored prompts are enabled, use a standard color scheme. otherwise, default.
if [ "$color_prompt" = yes ]; then
  PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
  PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt
# sets the title bar of xterm or rxvt terminals to user@host:directory
case "$TERM" in
  xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
  *)
    ;;
esac
# color support for 'ls', 'grep', etc.
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" \
    || eval "$(dircolors -b)"
  alias ls='ls --color=auto'
  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi
# example: display the username in green, then run the 'ip' function,
# followed by the current directory in blue.
Color_Username="\[\033[01;32m\]"
Color_Hostname="\[\033[00m\]"
Color_Path="\[\033[01;34m\]"
PS1="$Color_Username\u$Color_Hostname@\$(ip) $Color_Path\W "

## eof
