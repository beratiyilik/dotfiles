#!/usr/bin/env bash
# Source-only library (see docs/INTERNALS.md). Idempotent: guarded
# against double-sourcing via __DF_DETECT_LOADED. Pure leaf: sources nothing and
# uses no $DOTFILES, so it carries no assertion.
[[ -n "${__DF_DETECT_LOADED:-}" ]] && return 0
readonly __DF_DETECT_LOADED=1

detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        *)      echo "unknown" ;;
    esac
}

# Reports the running interpreter via shell-set version vars, which are
# authoritative for the current process (independent of $SHELL). Falls back
# to the $SHELL basename, then sh, for non-bash/zsh interpreters (e.g. dash).
detect_shell() {
  if [[ -n "${BASH_VERSION:-}" ]]; then
    printf '%s\n' bash
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    printf '%s\n' zsh
  else
    local sh="${SHELL:-sh}"
    printf '%s\n' "${sh##*/}"
  fi
}

detect_python() {
    if command -v python3 &>/dev/null; then
        echo "python3"
    else
        echo ""
    fi
}
