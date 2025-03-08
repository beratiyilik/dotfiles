#!/bin/zsh

# amazon q pre block. keep at the top of this file
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"

# powerlevel10k instant prompt (keep at the top for speed)
[[ -r "$XDG_CACHE_HOME/p10k-instant-prompt-${(%):-%n}.zsh" ]] && source "$XDG_CACHE_HOME/p10k-instant-prompt-${(%):-%n}.zsh"

# ============================================================
# CORE ENVIRONMENT VARIABLES & PATH SETTINGS
# ============================================================

# brew (a.k.a. homebrew)
export BREW_DIR="/opt/homebrew"
export PATH="$BREW_DIR/bin:$BREW_DIR/sbin:$PATH"
export MANPATH="$BREW_DIR/share/man:$MANPATH"
export INFOPATH="$BREW_DIR/share/info:$INFOPATH"

# common flags if needed
[[ -z "$LDFLAGS" ]] && export LDFLAGS=""
[[ -z "$CPPFLAGS" ]] && export CPPFLAGS=""

# python and pyenv
# export PATH="$HOME/Library/Python/3.9/bin:$PATH"
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

# docker
# export PATH="$BREW_DIR/opt/docker/bin:$PATH"
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"

# code
export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"

# cmake
export PATH="$BREW_DIR/opt/cmake/bin:$PATH"

# dotnet
export DOTNET_ROOT="$BREW_DIR/opt/dotnet-sdk"
export PATH="$HOME/.dotnet/tools:$PATH"

# llvm
export PATH="$BREW_DIR/opt/llvm/bin:$PATH"
export LDFLAGS="$LDFLAGS -L$BREW_DIR/opt/llvm/lib"
export CPPFLAGS="$CPPFLAGS -I$BREW_DIR/opt/llvm/include"

# openssl
export PATH="$BREW_DIR/opt/openssl@3/bin:$PATH"
export LDFLAGS="$LDFLAGS -L$BREW_DIR/opt/openssl@3/lib"
export CPPFLAGS="$CPPFLAGS -I$BREW_DIR/opt/openssl@3/include"

# ruby and rbenv
export PATH="$BREW_DIR/opt/ruby/bin:$PATH"
if command -v rbenv &> /dev/null; then
  eval "$(rbenv init -)"
fi

# bat (cat with syntax highlighting)
export LESSOPEN="| bat --paging=never %s"
export LESS=" -R "

# wireshark and tshark
export PATH="/Applications/Wireshark.app/Contents/MacOS:$PATH"
# sudo ln -s /Applications/Wireshark.app/Contents/MacOS/wireshark /usr/local/bin/wireshark
# sudo ln -s /Applications/Wireshark.app/Contents/MacOS/tshark /usr/local/bin/tshark

# azure data studio
# export PATH="/Applications/Azure Data Studio.app/Contents/Resources/app/bin:$PATH"

# cursor
# export PATH="/Applications/Cursor.app/Contents/Resources/app/bin:$PATH"

# coteditor
export PATH="/Applications/CotEditor.app/Contents/SharedSupport/bin:$PATH"

# ============================================================
# CUSTOM ENVs, FUNCTIONS AND ALIASES
# ============================================================

# [[ -f "$HOME/.zshenv" ]] && source "$HOME/.zshenv"         # custom envs
[[ -f "$SH_FUNCTIONS_DIR" ]] && source "$SH_FUNCTIONS_DIR"   # custom functions
[[ -f "$SH_ALIASES_DIR" ]] && source "$SH_ALIASES_DIR"       # custom aliases

# ============================================================
# OH-MY-ZSH, PLUGINS AND CONFIGURATIONS
# ============================================================

export ZSH=$HOME/.oh-my-zsh
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git fzf autojump direnv sudo tmux python pip virtualenv pyenv node npm yarn nvm golang rust gradle dotnet docker docker-compose kubectl zsh-syntax-highlighting zsh-history-substring-search fast-syntax-highlighting colored-man-pages alias-finder extract)
source $ZSH/oh-my-zsh.sh
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# history-substring-search plugin keybinds
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# fzf integration
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# autojump integration
[[ -f /usr/share/autojump/autojump.zsh ]] && source /usr/share/autojump/autojump.zsh

# zoxide (alternative to autojump)
[[ -f "$BREW_DIR/etc/profile.d/zoxide.sh" ]] && source "$BREW_DIR/etc/profile.d/zoxide.sh"
eval "$(zoxide init zsh)"

# ============================================================
# DEVELOPMENT TOOLS, FRAMEWORKS, SDKs AND ENVIRONMENTS
# ============================================================

# nvm
export NVM_DIR="$HOME/.nvm"
[[ -s "$BREW_DIR/opt/nvm/nvm.sh" ]] && source "$BREW_DIR/opt/nvm/nvm.sh"
[[ -s "$BREW_DIR/opt/nvm/etc/bash_completion.d/nvm" ]] && source "$BREW_DIR/opt/nvm/etc/bash_completion.d/nvm"

# aws
[[ -f "$AWS_HELPERS_DIR" ]] && source "$AWS_HELPERS_DIR"

# esp-idf
[[ -f "$ESP_IDF_HELPERS_DIR" ]] && source "$ESP_IDF_HELPERS_DIR"

# amazon q post block. keep at the bottom of this file
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"

## eof
