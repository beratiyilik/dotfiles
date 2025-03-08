#!/bin/zsh

# ============================================================
# this file is read only by login shells.
# place commands/environments that should run once per login,
# not in every interactive shell or script.
# ============================================================

# amazon q pre block. keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zprofile.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zprofile.pre.zsh"

# 1) Source .zshenv if it exists (so login shells get its env vars)
[[ -f "$HOME/.zshenv" ]] && source "$HOME/.zshenv"

# 2) If this is an interactive shell, optionally source .zshrc
#    so you don’t miss aliases/functions/plugins.
#    (Sometimes you might not want to do this, but it’s common.)
[[ -o interactive && -f "$HOME/.zshrc" ]] && source "$HOME/.zshrc"

# 3) Add any login-specific commands you want to run exactly once.
#    For example, you could:
#    - Run security checks
#    - Print a welcome message
#    - Tweak PATH or environment specifically for login
#    - Start an agent or background service

# Example (print a greeting if you want):
# echo "Welcome, $USER! You're logged into $(hostname). It's currently $(date '+%A, %B %d, %Y %I:%M %p')."
echo "👨‍💻 $USER@$(hostname) | 📅 $(date '+%a %b %-d %I:%M %p')"
# echo "👨‍💻 $USER@$(hostname) | 📁 $(pwd) | 🖥️  RAM: $(top -l 1 | awk '/PhysMem/ {print $2 " used / " $6 " total"}') | 💾 Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2}') | ⏳ Uptime: $(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1 " " $2}') | 📅 $(date '+%a %b %-d %I:%M %p')"

# 4) (Optional) If you want to load shell functions, aliases,
#    or other files only for login shells, you could explicitly
#    source them here. In many setups, we let .zshrc do that, but
#    you can do so here if you prefer:

# [[ -f "$HOME/.zsh_functions" ]] && source "$HOME/.zsh_functions"
# [[ -f "$HOME/.zsh_aliases" ]] && source "$HOME/.zsh_aliases"

# amazon q post block. keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zprofile.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zprofile.post.zsh"

## eof
