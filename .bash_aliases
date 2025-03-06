#!/bin/bash

# basic listing commands
alias la="ls -AF"                   # list all files (including hidden, except . and ..)
alias l1="ls -1AF"                  # list files (one per line)
alias ll="ls -lhAF"                 # list all files with detailed info (long format, human-readable sizes)

# directory-specific listings
alias ld="ls -d */"                 # list only directories
alias lp="ls -d `pwd`/*"            # list full file paths

# sorting by time (modification time)
alias lt="ls -Alt"                  # sort by modification time (latest first)
alias ltr="ls -Altr"                # sort by modification time (oldest first)

# sorting by size
alias lss="ls -AFlS"                # sort by size (largest first)
alias lsr="ls -AFlSr"               # sort by size (smallest first)

# filtering and searching
alias l.="ls -A | egrep '^\.'"      # list only dotfiles (hidden files)
alias lg="ls -AF | grep"            # search for filenames using grep
alias lpg="ls -d `pwd`/* | grep"    # search for filenames but list full path

# network utilities
alias pubip="dig +short txt ch whoami.cloudflare @1.0.0.1"
alias prvip="ipconfig getifaddr en0"
alias ips="ifconfig -a | grep -o 'inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\}[0-9]\+\)\|[a-fA-F0-9:]\+\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'"

# system utilities
alias c="clear"         # clear terminal screen
alias cl="clear; la"    # clear and list all files
alias cld="clear; ld"   # clear and list directories
alias cl.="clear; l."   # clear and list hidden files
alias cls="clear; ls"   # clear and run ls

# quick navigation
alias ..="cd .."                # go up one level
alias ...="cd ../.."            # go up two levels
alias ....="cd ../../.."        # go up three levels
alias .....="cd ../../../.."    # go up four levels
alias ~="cd ~"                  # go to home directory
alias -- -="cd -"               # go to previous directory

# workspace shortcut
alias wd="cd $WORKSPACE_DIR"

# clipboard utilities
if command -v xclip &> /dev/null; then
  alias cpy="xclip -selection clipboard"
  alias cpyf="xclip -selection clipboard <"
  alias pst="xclip -selection clipboard -o"
  alias pstf="xclip -selection clipboard -o >"
elif command -v xsel &> /dev/null; then
  alias cpy="xsel --clipboard --input"
  alias pstf="xsel --clipboard --input <"
  alias pst="xsel --clipboard --output"
  alias pstf="xsel --clipboard --output >"
fi

# update all system packages
alias update="sudo sh -c 'apt-get -y update;apt-get -y dist-upgrade;apt-get -y autoremove;apt-get -y autoclean'"

# remove unnecessary os system files
# alias cleanup="sudo sh -c 'apt-get -y autoremove;apt-get -y autoclean'"

# empty trash and logs
# alias emptytrash="rm -rf ~/.local/share/Trash/*"
 
# kill processes running on specific ports
alias kp="_killProcessesOnPorts"

# file backup and archive utilities
alias bkf="_bakFile"    # backup file
# alias tarc="_tarc"      # create tar archive
# alias tarx="_tarx"      # extract tar archive
# alias extr="_extract"   # extract any compressed file format

## eof
