# shellcheck shell=bash
# [ -f "$DOTFILES_DIR/lib/aliases.sh" ] && . "$DOTFILES_DIR/lib/aliases.sh"

#############################################################################
# ENVIRONMENT DETECTION - do this once at the beginning
#############################################################################

IS_MACOS=0
IS_LINUX=0
IS_WSL=0
IS_ZSH=0
IS_BASH=0

# shell detection (works when sourced; $0 is unreliable across shells)
if [ -n "${ZSH_VERSION:-}" ]; then
    IS_ZSH=1
elif [ -n "${BASH_VERSION:-}" ]; then
    IS_BASH=1
fi

# os detection
case "$(uname -s)" in
    Darwin*)
        IS_MACOS=1
        ;;
    Linux*)
        IS_LINUX=1
        if [ -r /proc/sys/kernel/osrelease ]; then
            case "$(cat /proc/sys/kernel/osrelease)" in
                *[Mm]icrosoft*|*WSL*) IS_WSL=1 ;;
            esac
        elif [ -r /proc/version ]; then
            case "$(cat /proc/version)" in
                *[Mm]icrosoft*|*WSL*) IS_WSL=1 ;;
            esac
        fi
        ;;
esac

#############################################################################
# COMMAND REPLACEMENTS - define these first to avoid conflicts
#############################################################################

# initialize dircolors if available
if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b)"
fi

# useful aliases and colored output
if command -v eza >/dev/null 2>&1; then
  alias ls="eza --icons --group-directories-first"
  alias ll="eza -lha --icons --group-directories-first --git"
  alias la="eza -la --icons --group-directories-first"
  alias l="eza --icons --group-directories-first --oneline"
  alias lt="eza -lhaT --icons --group-directories-first --git"
  alias lta="eza -lhaT --icons --group-directories-first"
  alias tree="eza --tree --icons --all --ignore-glob='.git,node_modules,*.log'"
else
  _ls_group=""
  ls --group-directories-first / >/dev/null 2>&1 && _ls_group="--group-directories-first"
  alias ls="ls --color=auto -F $_ls_group"
  alias ll="ls -lha --color=auto -F $_ls_group"
  alias la="ls -A --color=auto -F $_ls_group"
  alias l="ls -CF --color=auto -F $_ls_group"
  alias lt="ls -lhaR --color=auto -F $_ls_group"
  alias lta="ls -lhaR --color=auto -F $_ls_group"
  alias tree="find . -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'"
fi

# better cat and less with bat (if installed)
if command -v bat >/dev/null 2>&1; then
  alias cat="bat --style=plain"
  alias less="bat --paging=always"
fi

# use ripgrep instead of grep if available
# if command -v rg >/dev/null 2>&1; then
#   alias grep="rg"
# fi

# use colordiff if available
if command -v colordiff >/dev/null 2>&1; then
  alias diff="colordiff -u"
else
  alias diff="diff -u"
fi

# use fd instead of find if available
# if command -v fd >/dev/null 2>&1; then
#   alias find="fd"
# fi

#############################################################################
# FILE OPERATIONS
#############################################################################

# directory creation
alias mkdir='mkdir -pv' # make parent directories as needed
alias mkcd="_mkcd"      # create and navigate to directory in one step

# file copying/moving
alias cp='cp -iv' # confirm before overwriting
alias mv='mv -iv' # confirm before overwriting

# file deletion
alias rm='rm -iv'   # confirm before deleting
alias rmrf='rm -rf' # force remove recursively (use with caution!)

# archive utilities
alias zp="zip -r"         # zip recursively
alias untar='tar -xzvf'   # extract .tar.gz files
alias untarbz='tar -xjvf' # extract .tar.bz2 files

# file hashing
alias md5="openssl md5"
alias sha1="openssl sha1"
# alias sha256="_generateHash"

alias tspid="_tspid" # generate timestamped unique ID based on current time and PID

#############################################################################
# FILE LISTING ALIASES
#############################################################################

# basic listing commands (ll, la, lt already defined in the eza/ls block above)
alias l1="ls -1AF"          # list files (one per line)
alias llg="ls -lhAF | grep" # list files and filter with grep

# directory-specific listings
alias ld="ls -d */"                 # list only directories
alias lda="ls -dA */"               # list all directories including hidden ones
# shellcheck disable=SC2139
alias lp='ls -d "$(pwd)"/*'         # list files in current directory (expands at use time)
# shellcheck disable=SC2139
alias lpg='ls -d "$(pwd)"/* | grep' # list files in current directory and filter with grep

# sorting
alias ltr="ls -Altr"  # sort by modification time (oldest first)
alias lss="ls -AFlS"  # sort by size (largest first)
alias lsr="ls -AFlSr" # sort by size (smallest first)

# filtering and searching
alias l.="ls -A | grep '^\\.'" # list only dotfiles (hidden files)
alias lg="ls -AF | grep"       # search for filenames using grep

# compound aliases that depend on other ls aliases - defined after ls is set up
alias c="clear"       # clear
alias cl="clear; la"  # clear and list all files
alias cld="clear; ld" # clear and list directories
alias cl.="clear; l." # clear and list hidden files
alias cls="clear; ls" # clear and run ls

#############################################################################
# NAVIGATION ALIASES
#############################################################################

# quick navigation
alias ..="cd .."             # go up one level
alias ...="cd ../.."         # go up two levels
alias ....="cd ../../.."     # go up three levels
alias .....="cd ../../../.." # go up four levels
alias ~="cd ~"               # go to home directory
alias -- -="cd -"            # go to previous directory

# workspace and common directories
alias rp='z $REPOS_DIR'            # alias wd="cd $REPOS_DIR"
alias docs='z ~/Documents'         # alias docs="cd ~/Documents"
alias dls='z ~/Downloads'          # alias dls="cd ~/Downloads"
alias desk='z ~/Desktop'           # alias desk="cd ~/Desktop"
alias od='z ~/OneDrive'            # alias od="cd ~/OneDrive"
alias odd='z ~/OneDrive/documents' # alias odd="cd ~/OneDrive/documents"
alias logs='z $LOG_DIR'            # alias logs="cd $LOG_DIR"
alias caches='z $CACHE_DIR'        # alias caches="cd $CACHE_DIR"

# directory stack commands
alias d='dirs -v' # display directory stack
alias 1='cd -1'   # go to 1st directory in stack
alias 2='cd -2'   # go to 2nd directory in stack
alias 3='cd -3'   # go to 3rd directory in stack
alias 4='cd -4'   # go to 4th directory in stack

# quick bookmarks (requires direnv or similar tool)
alias save='pwd > ~/.last_dir'
alias jmp='cd "$(cat ~/.last_dir)"'

#############################################################################
# SYSTEM AND UTILITY ALIASES
#############################################################################

# system information
alias df='df -h'           # human-readable disk usage
alias du='du -h'           # human-readable file size
alias dus='du -hs'         # summarize disk usage
alias dud='du -hd1'        # disk usage by directory (depth 1)
alias free='free -m'       # display free memory in MB
alias dusage='_disk_usage' # custom disk usage function
alias battery="pmset -g batt" # show battery status on macOS
# alias battery-cycle="system_profiler SPPowerDataType | grep "Cycle Count" | awk '{print $3}'"

# process management
# use procs instead of ps if available (affects psa, psg, psmem, pscpu)
if command -v procs >/dev/null 2>&1; then
  alias ps='procs'
fi
# use htop instead of top if available
if command -v htop >/dev/null 2>&1; then
  alias top='htop'
fi
alias psa="ps aux"                           # list all processes
alias psg="ps aux | grep -v grep | grep -i"  # search processes by name
alias psmem="ps aux | sort -rnk 4,4"         # sort by memory usage, highest first
alias pscpu="ps aux | sort -rnk 3,3"         # sort by CPU usage, highest first
alias kp="_kport"                            # kill processes on port(s)
alias kport="_kport"                         # backward-compat public name
alias fkill='_fzf_kill'                      # fzf interactive process killer 

# editor and pager
alias e='${EDITOR:-nano}'   # open in default editor
alias view='${PAGER:-less}' # open in default pager
alias vi="vim"              # make sure vi is vim

# file search
alias ff="find . -type f -name" # find file by name
# alias fd="find . -type d -name"  # find directory by name (only if fd command not available)
alias ftext="grep -r"      # find text in files
alias fsize="find . -size" # find files by size
alias search="_fzf_search" # search files with preview using fzf and bat

#############################################################################
# NETWORK UTILITIES
#############################################################################

# ip addresses
alias pubip="dig +short txt ch whoami.cloudflare @1.0.0.1 | tr -d '\"' || curl -s https://ipinfo.io/ip"
if [[ $IS_MACOS -eq 1 ]]; then
  alias prvip="ipconfig getifaddr en0"
  alias ip="ipconfig getifaddr en0"
else
  alias prvip="ip route get 1 | awk '{print \$7}'"
  alias ip="hostname -I | awk '{print \$1}'"
fi
alias ips="ifconfig -a | grep -o 'inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\}[0-9]\+\)\|[a-fA-F0-9:]\+\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'"
alias externIp="curl ifconfig.me"

# network tools
alias ping='ping -c 5'                   # ping with count of 5
alias ports='netstat -tulanp'            # show open ports
alias http='python3 -m http.server 8000' # simple http server

# url utilities
alias urlencode='python3 -c "import sys, urllib.parse as ul; print(ul.quote_plus(sys.argv[1]))"'
alias urldecode='python3 -c "import sys, urllib.parse as ul; print(ul.unquote_plus(sys.argv[1]))"'

# dns lookup utilities
alias dig1="dig +short"      # short dns lookup
alias dns="dig +answer"      # dns lookup with answer
alias dig-trace="dig +trace" # dns lookup with trace

# flush DNS cache (macOS specific)
if [[ $IS_MACOS -eq 1 ]]; then
  alias flush="sudo killall -HUP mDNSResponder"
  alias flush-dns="sudo killall -HUP mDNSResponder"
fi

#############################################################################
# CLIPBOARD AND TEXT UTILITIES
#############################################################################

# clipboard commands based on OS
if [ "$IS_MACOS" -eq 1 ]; then
    alias cpy="pbcopy"      # copy to clipboard 
    alias pst="pbpaste"     # paste from clipboard
    cpyf() { pbcopy < "$1"; }
    pstf() { pbpaste > "$1"; }
elif [ "$IS_WSL" -eq 1 ]; then
    alias cpy="clip.exe"
    alias pst="powershell.exe -NoProfile -Command Get-Clipboard"
    cpyf() { clip.exe < "$1"; }
    pstf() { powershell.exe -NoProfile -Command Get-Clipboard > "$1"; }
elif command -v wl-copy >/dev/null 2>&1; then
    alias cpy="wl-copy"
    alias pst="wl-paste"
    cpyf() { wl-copy < "$1"; }
    pstf() { wl-paste > "$1"; }
elif command -v xclip >/dev/null 2>&1; then
    alias cpy="xclip -selection clipboard"
    alias pst="xclip -selection clipboard -o"
    cpyf() { xclip -selection clipboard < "$1"; }
    pstf() { xclip -selection clipboard -o > "$1"; }
elif command -v xsel >/dev/null 2>&1; then
    alias cpy="xsel --clipboard --input"
    alias pst="xsel --clipboard --output"
    cpyf() { xsel --clipboard --input < "$1"; }
    pstf() { xsel --clipboard --output > "$1"; }
fi

# text processing
alias trim="sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*\$//g'"
alias lowercase="tr '[:upper:]' '[:lower:]'"
alias uppercase="tr '[:lower:]' '[:upper:]'"
alias count='wc -l'                      # count lines
alias sum="awk '{s+=\$1} END {print s}'" # sum a column of numbers
alias json="python3 -m json.tool"        # format JSON

#############################################################################
# DEVELOPMENT ALIASES
#############################################################################

# node.js
alias node-dev="node --inspect --trace-warnings"
alias npm-root="npm root -g"
alias npml="npm list --depth=0"
alias npmlg="npm list -g --depth=0"
alias nrm="npm run" # npm run shorthand

# docker
alias dokcer="docker" # common typo fallback
alias dps='docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias drm="docker rm -f"
alias dl="docker logs -f"
alias dex="docker exec -it"
# alias dsh="dsh() { docker exec -it \"$1\" sh || docker exec -it \"$1\" bash; }"
alias di="docker images"
alias db="docker build"
alias dri="docker rmi -f"
alias dpurge="docker system prune -a --volumes"
alias dc="docker compose"
alias dcu="docker compose up -d"
alias dcs="docker compose stop"
alias dcd="docker compose down"
alias dcd2="docker compose down --remove-orphans --volumes --rmi all"
alias dcr="docker compose restart"

# python
# alias py="python3"
# alias pip="pip3"
# alias venv="python3 -m venv venv"
# alias activate="source venv/bin/activate"
# alias pyserver="python -m http.server"
alias update-py="pip3 list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip3 install -U"

# git
# note: git aliases are defined in git_helpers.sh

# ai
alias ai_rename="_ai_rename" # rename file based on content via local AI model

# code editors
alias code="_code" # unified alias to open different code editors
alias bashrc="cot ~/.bashrc"
alias zshrc="cot ~/.zshrc"
alias flb="p format && p lint && p build"

# window manager (yabai/skhd) - macOS specific
if [[ $IS_MACOS -eq 1 ]]; then
  alias tiling-start="yabai --start-service && skhd --start-service"
  alias tiling-stop="yabai --stop-service && skhd --stop-service"
fi

#############################################################################
# TERMINAL UTILITIES
#############################################################################

# history
alias h="history"
alias h1="history 10"
alias h2="history 20"
alias h3="history 30"
alias hgrep="history | grep" # search history
alias clh="history -c"       # clear history
alias fhist="_fzf_history"      # fzf search through command history

# terminal
alias trm="_trm_new_window"
alias trmlight="_trm_new_window -p solarized-light"
alias trmdark="_trm_new_window -p solarized-dark"
alias trmubuntu="_trm_new_window -p ubuntu"
alias trmhere="_trm_reopen_here"
alias trmxs="_trm_resize xs"
alias trmsmall="_trm_resize small"
alias trmmedium="_trm_resize medium"
alias trmlarge="_trm_resize large"
alias trmxl="_trm_resize xl"
alias path="_display_path_entries"                 # show path entries one per line
alias reload="_safe_source $SHELL_RC_PATH"         # reload shell configuration
alias bash3="_switch_to_bash bash"                 # switch to bash3
alias bash5="_switch_to_bash bash5"                # switch to bash5
alias tm="tmux"                                    # tmux shortcut
alias tmlocalai="bash \$DOTFILES_DIR/config/tmux/.tmux.localai.sh" # local AI dev session
alias shellinfo="\$DOTFILES_DIR/scripts/shell_diagnostics.sh" # shell info script

# date and time
alias now="_now"
alias utc="_utc"
alias epoch="_get_timestamp"
alias tz="_timezones"

# calculator
alias calc="bc -l"

# weather
alias weather="curl -s 'wttr.in/{SanFrancisco,Istanbul,London}?format=3'"
alias forecast="curl -s wttr.in/London"

# security
alias genpass="_genpass"   # generate secure password
alias ssha="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" # ssh without host checks

# macOS specific terminal utilities
if [[ $IS_MACOS -eq 1 ]]; then
  alias rest="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"
  alias badge="tput bel" # terminal bell
fi

#############################################################################
# SYSTEM & SOFTWARE UPDATE ALIASES
#############################################################################

if [[ $IS_MACOS -eq 1 ]]; then
  alias update="\$DOTFILES_DIR/scripts/macos/update.zsh"
  alias cleanup="\$DOTFILES_DIR/scripts/macos/cleanup.zsh"
  alias maintain="\$DOTFILES_DIR/scripts/macos/update.zsh && \$DOTFILES_DIR/scripts/macos/cleanup.zsh -a"
  alias maintain-full="\$DOTFILES_DIR/scripts/macos/update.zsh --yes && \$DOTFILES_DIR/scripts/macos/cleanup.zsh -a --yes"
  alias backup="\$DOTFILES_DIR/scripts/macos/backup.zsh"
  alias backup-full="\$DOTFILES_DIR/scripts/macos/backup.zsh --all"
  alias brewfile-update="brew bundle dump --file=\$DOTFILES_DIR/config/homebrew/Brewfile --force"
elif command -v apt-get >/dev/null 2>&1; then
  alias update="sudo sh -c 'apt-get -y update;apt-get -y dist-upgrade;apt-get -y autoremove;apt-get -y autoclean'"
fi

#############################################################################
# FINDER & MACOS-SPECIFIC ALIASES
#############################################################################

if [[ $IS_MACOS -eq 1 ]]; then
  # show/hide hidden files
  alias showfiles="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
  alias hidefiles="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

  # hide/show desktop icons
  alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"
  alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"

  # cleanup operations
  alias cleanup-ds='command -v fd >/dev/null && fd -HI --type f DS_Store -x rm {} || find . -type f -name .DS_Store -print -delete'

  # empty trash
  alias emptytrash='sudo find /Volumes -mindepth 2 -maxdepth 2 -name .Trashes -exec rm -rfv {} + 2>/dev/null; [[ -n "$(ls -A ~/.Trash 2>/dev/null)" ]] && sudo rm -rfv ~/.Trash/* 2>/dev/null; sudo find /private/var/log/asl -name "*.asl" -delete 2>/dev/null; sqlite3 "$(ls ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* 2>/dev/null | head -1)" "DELETE FROM LSQuarantineEvent" 2>/dev/null'

  # speed up Terminal
  alias speedup="sudo rm -rf /private/var/log/asl/*"

  # spotlight control
  alias spotoff="sudo mdutil -a -i off"
  alias spoton="sudo mdutil -a -i on"

  # application launch shortcuts
  alias safari="open /Applications/Safari.app"

  # find App Store apps
  alias find_apps='mdfind kMDItemAppStoreHasReceipt=1'
fi

## eof