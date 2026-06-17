#!/usr/bin/env bash
# Debian/Ubuntu package install. Sourced by `dotfiles init` (linux) and
# `dotfiles os` (linux). Runs under set -e, so it is fault-tolerant.
[[ "$(uname -s)" == "Linux" ]] || return 0

: "${DOTFILES:?DOTFILES not set — run via bin/dotfiles}"
source "$DOTFILES/core/utils.sh"   # idempotent (self-guarded)

APT=""
has_cmd apt-get && APT="apt-get"
has_cmd apt && APT="apt"
if [[ -z "$APT" ]]; then
    log_warn "apt not found, skipping linux package install."
    return 0
fi

SUDO=""
[[ "$(id -u)" -ne 0 ]] && SUDO="sudo"

pkgfile="$DOTFILES/os/linux/packages.txt"
[[ -f "$pkgfile" ]] || { log_warn "packages.txt missing, skipping."; return 0; }

# Drop comments and blank lines, collect the package list.
packages=()
while IFS= read -r line; do
    line="${line%%#*}"               # strip trailing comment
    line="$(echo "$line" | xargs)"   # trim
    [[ -z "$line" ]] && continue
    packages+=("$line")
done < "$pkgfile"

[[ ${#packages[@]} -eq 0 ]] && { log_warn "packages.txt is empty."; return 0; }

log_info "apt update..."
$SUDO "$APT" update || log_warn "apt update failed"
log_info "apt install: ${packages[*]}"
$SUDO "$APT" install -y "${packages[@]}" || log_warn "some packages could not be installed"
log_ok "linux packages processed."
