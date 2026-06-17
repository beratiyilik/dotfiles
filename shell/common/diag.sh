# shellcheck shell=bash
# Sourced by .zshrc / .bashrc. Defines the `shelldiag` function.
#
# =============================================================================
# diag.sh — shell environment diagnostics (Bash + Zsh)
#
# `shelldiag` reports the LIVE interactive shell: type/version, mode, option and
# alias/function counts, user, system, terminal, and PATH. It is a sourced
# function on purpose — a separate process (e.g. a Python child) cannot see the
# parent shell's version vars, $- flags, shopt/setopt state, aliases, or
# functions, which are the whole point of the report.
#
# Usage:  shelldiag [-h] [--no-color] [--minimal]
#
# This file MUST NOT change shell options (no set -e / IFS) at source time, or
# it would alter the interactive shell that sources it. Colour variables are
# function-local; the global environment is left untouched.
# =============================================================================

# _diag_line <char> <length>
_diag_line() { printf '%*s\n' "${2:-40}" '' | tr ' ' "${1:-=}"; }

# _diag_header <title>   (reads dynamically-scoped colours + $_diag_minimal)
_diag_header() {
  if [ "${_diag_minimal:-0}" = 1 ]; then printf "\n%s:\n" "$1"; return 0; fi
  printf "\n%b%s%b\n" "${STYLE_BOLD:-}${FG_GREEN:-}" "$1" "${STYLE_RESET:-}"
  printf "%b%s%b\n" "${FG_BLUE:-}" "$(_diag_line '-' 40)" "${STYLE_RESET:-}"
}

# _diag_item <label> <value>
_diag_item() {
  [ -n "$2" ] || return 0
  if [ "${_diag_minimal:-0}" = 1 ]; then printf "%s: %s\n" "$1" "$2"; return 0; fi
  printf "%-20s %b%s%b\n" "$1:" "${STYLE_BOLD:-}" "$2" "${STYLE_RESET:-}"
}

shelldiag() {
  local _diag_minimal=0 nocolor=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        printf "usage: shelldiag [-h] [--no-color] [--minimal]\n"
        printf "  report the current shell environment\n"
        return 0 ;;
      -n | --no-color) nocolor=1 ;;
      --minimal)       _diag_minimal=1 ;;
      *) printf "shelldiag: unknown option: %s\n" "$1" >&2; return 64 ;;
    esac
    shift
  done

  # colours are function-local; helpers see them via dynamic scope
  local STYLE_BOLD STYLE_RESET FG_BLUE FG_GREEN FG_RED FG_YELLOW
  if [ "$nocolor" = 0 ] && [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    STYLE_BOLD=$(tput bold 2>/dev/null);  STYLE_RESET=$(tput sgr0 2>/dev/null)
    FG_BLUE=$(tput setaf 4 2>/dev/null);  FG_GREEN=$(tput setaf 2 2>/dev/null)
    FG_RED=$(tput setaf 1 2>/dev/null);   FG_YELLOW=$(tput setaf 3 2>/dev/null)
  else
    STYLE_BOLD=""; STYLE_RESET=""; FG_BLUE=""
    FG_GREEN=""; FG_RED=""; FG_YELLOW=""
  fi

  [ "$_diag_minimal" = 1 ] || printf "%b%s%b\n%bShell Diagnostics%b  %s\n%b%s%b\n" \
    "${STYLE_BOLD:-}${FG_BLUE:-}" "$(_diag_line '=' 40)" "${STYLE_RESET:-}" \
    "${STYLE_BOLD:-}" "${STYLE_RESET:-}" "$(date '+%Y-%m-%d %H:%M:%S')" \
    "${FG_BLUE:-}" "$(_diag_line '=' 40)" "${STYLE_RESET:-}"

  # --- shell -------------------------------------------------------------
  _diag_header "SHELL"
  local mode=""
  case "$-" in *i*) mode="interactive" ;; *) mode="non-interactive" ;; esac
  if [ -n "${BASH_VERSION:-}" ]; then
    _diag_item "Type" "bash ${BASH_VERSION}"
    if shopt -q login_shell 2>/dev/null; then mode="$mode, login"; else mode="$mode, non-login"; fi
    _diag_item "Mode" "$mode"
    _diag_item "Options on" "$(shopt 2>/dev/null | grep -c 'on$')"
  elif [ -n "${ZSH_VERSION:-}" ]; then
    _diag_item "Type" "zsh ${ZSH_VERSION}"
    if [[ -o login ]] 2>/dev/null; then mode="$mode, login"; else mode="$mode, non-login"; fi
    _diag_item "Mode" "$mode"
    _diag_item "Options set" "$(setopt 2>/dev/null | wc -l | tr -d ' ')"
  else
    _diag_item "Type" "unknown / POSIX sh"
    _diag_item "Mode" "$mode"
  fi
  _diag_item "PID" "$$"
  local ppid pname
  ppid=$(ps -o ppid= -p "$$" 2>/dev/null | tr -d ' ')
  if [ -n "$ppid" ]; then
    pname=$(ps -p "$ppid" -o comm= 2>/dev/null)
    _diag_item "Parent" "$pname ($ppid)"
  fi

  # --- capabilities (accurate because we run inside the live shell) ------
  _diag_header "CAPABILITIES"
  _diag_item "Aliases" "$(alias 2>/dev/null | wc -l | tr -d ' ')"
  if [ -n "${BASH_VERSION:-}" ]; then
    _diag_item "Functions" "$(declare -F 2>/dev/null | wc -l | tr -d ' ')"
  elif [ -n "${ZSH_VERSION:-}" ]; then
    _diag_item "Functions" "$(functions 2>/dev/null | grep -c '() {')"
  fi

  # --- user --------------------------------------------------------------
  _diag_header "USER"
  _diag_item "User" "$(whoami 2>/dev/null)"
  _diag_item "UID/GID" "$(id -u 2>/dev/null)/$(id -g 2>/dev/null)"
  _diag_item "Groups" "$(id -Gn 2>/dev/null | tr ' ' ',')"
  _diag_item "Working dir" "$(pwd 2>/dev/null)"
  _diag_item "Home" "${HOME:-}"

  # --- system ------------------------------------------------------------
  _diag_header "SYSTEM"
  _diag_item "OS" "$(uname -s 2>/dev/null) $(uname -r 2>/dev/null)"
  _diag_item "Arch" "$(uname -m 2>/dev/null)"
  if [ -f /etc/os-release ]; then
    _diag_item "Distribution" "$(grep -E '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '\"')"
  elif command -v sw_vers >/dev/null 2>&1; then
    _diag_item "Distribution" "$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
  fi

  # --- terminal ----------------------------------------------------------
  _diag_header "TERMINAL"
  _diag_item "TTY" "$(tty 2>/dev/null)"
  _diag_item "TERM" "${TERM:-}"
  if command -v tput >/dev/null 2>&1; then
    local cols lines colors
    cols=$(tput cols 2>/dev/null); lines=$(tput lines 2>/dev/null)
    [ -n "$cols" ] && [ -n "$lines" ] && _diag_item "Size" "${cols}x${lines}"
    colors=$(tput colors 2>/dev/null)
    _diag_item "Colors" "$colors"
  fi

  # --- path & env --------------------------------------------------------
  _diag_header "PATH & ENVIRONMENT"
  # written out directly (portable; avoids eval / bash-only ${!v} indirection).
  # _diag_item skips empty values, so unset vars print nothing.
  _diag_item "SHELL"  "${SHELL:-}"
  _diag_item "LANG"   "${LANG:-}"
  _diag_item "LC_ALL" "${LC_ALL:-}"
  _diag_item "EDITOR" "${EDITOR:-}"
  _diag_item "VISUAL" "${VISUAL:-}"
  _diag_item "PAGER"  "${PAGER:-}"
  _diag_item "Env vars" "$(env 2>/dev/null | wc -l | tr -d ' ') total"

  [ "$_diag_minimal" = 1 ] || printf "%-20s\n" "PATH entries:"
  # awk dedups in a single pass (no temp file, no O(n^2) grep); the shell loop
  # only checks existence and adds colour. IFS=tab works in both bash and zsh.
  printf '%s' "${PATH:-}" | tr ':' '\n' \
    | awk 'length { print $0 "\t" (seen[$0]++ ? "dup" : "") }' \
    | while IFS=$'\t' read -r entry dflag; do
        dup=""
        [ "$dflag" = dup ] && dup=" ${FG_YELLOW:-}(dup)${STYLE_RESET:-}"
        if [ -d "$entry" ]; then
          printf "  %b[ok]%b %s%b\n" "${FG_GREEN:-}" "${STYLE_RESET:-}" "$entry" "$dup"
        else
          printf "  %b[missing]%b %s%b\n" "${FG_RED:-}" "${STYLE_RESET:-}" "$entry" "$dup"
        fi
      done

  [ "$_diag_minimal" = 1 ] || printf "\n%b%s%b\n" "${FG_BLUE:-}" "$(_diag_line '=' 40)" "${STYLE_RESET:-}"
}

## eof
