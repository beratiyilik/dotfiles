#!/usr/bin/env bash
# =============================================================================
# doctor.sh — dotfiles health check
#
# Compatible: bash 3.2+, zsh 5.0+
# Usage: ./doctor.sh [--fix]
#
# Reports on the health of the dotfiles installation. Checks symlinks,
# required directories, essential commands, and optional tool availability.
# Exit code 0 = all checks passed; non-zero = one or more failures.
#
# Options:
#   --fix    Re-run dotfiles init to repair any failed symlink checks
#   --help   Show this help and exit
# =============================================================================

# When called via `dotfiles doctor`, DOTFILES_DIR is exported by the CLI.
# When called standalone, detect it as the parent of this script's directory.
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
FIX=0

for _arg in "$@"; do
  case "$_arg" in
    --fix)  FIX=1 ;;
    -h | --help)
      printf 'Usage: %s [--fix]\n\n' "$0"
      printf '  --fix   Re-run dotfiles init to repair failed symlinks\n'
      exit 0
      ;;
    *)
      printf 'Unknown option: %s  (try --help)\n' "$_arg" >&2
      exit 1
      ;;
  esac
done

# ── colors ────────────────────────────────────────────────────────────────────
if [ -t 1 ] && command -v tput >/dev/null 2>&1 \
   && _nc="$(tput colors 2>/dev/null)" && [ "${_nc:-0}" -ge 8 ]; then
  R=$'\033[0m'  B=$'\033[1m'   G=$'\033[0;32m'  C=$'\033[0;36m'
  Y=$'\033[0;33m' RE=$'\033[0;31m'
else
  R='' B='' G='' C='' Y='' RE=''
fi

# ── counters ──────────────────────────────────────────────────────────────────
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

_ok()   { printf '%s[ok]%s  %s\n'  "$G"    "$R" "$*"; PASS_COUNT=$(( PASS_COUNT + 1 )); }
_warn() { printf '%s[!!]%s  %s\n'  "$Y"    "$R" "$*"; WARN_COUNT=$(( WARN_COUNT + 1 )); }
_fail() { printf '%s[XX]%s  %s\n'  "$B$RE" "$R" "$*" >&2; FAIL_COUNT=$(( FAIL_COUNT + 1 )); }
_section() {
  local _title="$*"
  printf '\n%s── %s ' "$B" "$_title"
  printf '%0.s─' {1..20}
  printf '%s\n' "$R"
}

# =============================================================================
# checks
# =============================================================================

# ── dotfiles dir ──────────────────────────────────────────────────────────────
_section "Dotfiles"

if [ -d "$DOTFILES_DIR" ]; then
  _ok "dotfiles directory: $DOTFILES_DIR"
else
  _fail "dotfiles directory not found: $DOTFILES_DIR  (run: dotfiles init)"
  printf '\n%sSummary:%s 0 passed  0 warnings  1 failed\n\n' "$B" "$R"
  exit 1
fi

# ── dotfiles.conf ─────────────────────────────────────────────────────────────
if [ -f "$DOTFILES_DIR/dotfiles.conf" ]; then
  # shellcheck disable=SC1091
  . "$DOTFILES_DIR/dotfiles.conf"
  _ok "dotfiles.conf loaded"
else
  _fail "dotfiles.conf not found: $DOTFILES_DIR/dotfiles.conf"
  printf '\n%sSummary:%s 0 passed  0 warnings  1 failed\n\n' "$B" "$R"
  exit 1
fi

# ── required directories ──────────────────────────────────────────────────────
_section "Directories"

for _d in "${DIRS[@]}"; do
  if [ -d "$HOME/$_d" ]; then
    _ok "$HOME/$_d"
  else
    _fail "$HOME/$_d  (missing — re-run: dotfiles init)"
  fi
done

# ~/.ssh with 700 permissions
if [ -d "$HOME/.ssh" ]; then
  _perms=$(stat -f "%Lp" "$HOME/.ssh" 2>/dev/null \
        || stat -c "%a"  "$HOME/.ssh" 2>/dev/null \
        || printf "unknown")
  if [ "$_perms" = "700" ]; then
    _ok "$HOME/.ssh (700)"
  else
    _warn "$HOME/.ssh permissions: ${_perms}  (expected 700 — run: chmod 700 $HOME/.ssh)"
  fi
else
  _fail "$HOME/.ssh (missing)"
fi

# ── symlinks ──────────────────────────────────────────────────────────────────
_section "Symlinks"

for _entry in "${SYMLINKS[@]}"; do
  _src="${_entry%%:*}"
  _rest="${_entry#*:}"
  _dst="${_rest%%:*}"
  _mode="${_rest#*:}"
  [ "$_mode" = "$_dst" ] && _mode=""

  _full_src="$DOTFILES_DIR/$_src"
  _full_dst="$HOME/$_dst"

  if [ ! -e "$_full_src" ]; then
    _warn "source missing: $_src"
    continue
  fi

  if [ ! -L "$_full_dst" ]; then
    _fail "not a symlink: $HOME/$_dst  (expected → $_full_src)"
  elif [ "$(readlink "$_full_dst")" = "$_full_src" ]; then
    if [ -n "$_mode" ]; then
      _actual=$(stat -L -f "%Lp" "$_full_dst" 2>/dev/null \
             || stat -L -c "%a"  "$_full_dst" 2>/dev/null \
             || printf "unknown")
      if [ "$_actual" = "$_mode" ]; then
        _ok "$HOME/$_dst → $_src ($_mode)"
      else
        _warn "$HOME/$_dst → $_src  (perms: ${_actual}, expected: ${_mode})"
      fi
    else
      _ok "$HOME/$_dst → $_src"
    fi
  else
    _actual_target=$(readlink "$_full_dst")
    _fail "$HOME/$_dst → wrong target: $_actual_target  (expected: $_full_src)"
  fi
done

# ── essential commands ────────────────────────────────────────────────────────
_section "Essential commands"

for _cmd in git zsh curl rsync; do
  if command -v "$_cmd" >/dev/null 2>&1; then
    _ok "$_cmd  ($(command -v "$_cmd"))"
  else
    _fail "$_cmd  (not found)"
  fi
done

# ── optional tools ────────────────────────────────────────────────────────────
_section "Optional tools"

for _cmd in brew fzf rg bat eza jq starship gh; do
  if command -v "$_cmd" >/dev/null 2>&1; then
    _ok "$_cmd"
  else
    _warn "$_cmd  (not installed — see Brewfile)"
  fi
done

# ── oh-my-zsh ─────────────────────────────────────────────────────────────────
_section "Oh My Zsh"

if [ -d "$HOME/.oh-my-zsh" ]; then
  _ok "oh-my-zsh installed"
else
  _warn "oh-my-zsh not found ($HOME/.oh-my-zsh)"
fi

_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for _entry in "${OMZ_PLUGINS[@]}"; do
  _label="${_entry%%|*}"
  _rest="${_entry#*|}"
  _subpath="${_rest##*|}"
  if [ -d "$_custom/$_subpath" ]; then
    _ok "  plugin: $_label"
  else
    _warn "  plugin: $_label  (not found at $_custom/$_subpath)"
  fi
done

# ── shell ─────────────────────────────────────────────────────────────────────
_section "Shell"

_current_shell=$(basename "${SHELL:-unknown}")
if [ "$_current_shell" = "zsh" ]; then
  _ok "default shell: zsh"
else
  _warn "default shell: ${_current_shell}  (expected zsh — run: chsh -s $(command -v zsh 2>/dev/null || printf zsh))"
fi

if command -v zsh >/dev/null 2>&1; then
  _ok "zsh version: $(zsh --version 2>/dev/null | head -1)"
fi

# =============================================================================
# summary
# =============================================================================

printf '\n%s──────────────────────────────────────────%s\n' "$B" "$R"
printf 'Summary:  '
printf '%s%d passed%s  '   "$G"  "$PASS_COUNT" "$R"
printf '%s%d warnings%s  ' "$Y"  "$WARN_COUNT" "$R"
printf '%s%d failed%s\n\n' "$RE" "$FAIL_COUNT" "$R"

if [ "$FIX" = "1" ] && [ "$FAIL_COUNT" -gt 0 ]; then
  printf '%sRe-running dotfiles init to repair failures...%s\n\n' "$C" "$R"
  "$DOTFILES_DIR/dotfiles" init
fi

[ "$FAIL_COUNT" -eq 0 ]

## eof
