#!/usr/bin/env bash
#
# dotfiles installer
#
# Local checkout:
#   ./install.sh
#
# Remote bootstrap (always fetches the latest installer):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/beratiyilik/dotfiles/HEAD/install.sh)"
#
# Behavior: from a local checkout it installs in place. Fetched remotely it
# clones into $DOTFILES (git preferred; tarball fallback when git is absent) and
# checks out the latest release tag when one exists, otherwise the default branch.
# Re-running the remote one-liner updates an existing clone in place.
#
# Environment overrides:
#   DOTFILES         install location                  (default: ~/dotfiles)
#   DOTFILES_SLUG    GitHub owner/repo                 (default: beratiyilik/dotfiles)
#   DOTFILES_BRANCH  branch tracked when no tag/ref    (default: main)
#   DOTFILES_REF     pin a specific tag/branch/commit  (default: latest tag, else branch)
#   DOTFILES_REPO    clone URL                         (default: https://github.com/$DOTFILES_SLUG.git)
#   NONINTERACTIVE   skip the confirmation prompt
#   CI               treated as NONINTERACTIVE

set -euo pipefail

# ----------------------------------------------------------------- output style
# Colorize only when stdout is a TTY, so piped/redirected output stays clean.
if [[ -t 1 ]]; then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_blue="$(tty_escape "1;34")"
tty_red="$(tty_escape "1;31")"
tty_bold="$(tty_escape "1;39")"
tty_reset="$(tty_escape 0)"

ohai() { printf "%s==>%s %s%s\n" "$tty_blue" "$tty_bold" "$*" "$tty_reset"; }
warn() { printf "%sWarning%s: %s\n" "$tty_red" "$tty_reset" "$*" >&2; }
abort() { printf "%sError%s: %s\n" "$tty_red" "$tty_reset" "$*" >&2; exit 1; }

# Friendly failure for any unguarded command. Commands in if/while/&&/|| or
# negated commands are exempt (same rules as set -e), so intentional non-zero
# returns stay silent.
trap 'abort "failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

# -------------------------------------------------------------------- arguments
usage() {
  cat <<EOS
dotfiles installer
Usage: [NONINTERACTIVE=1] install.sh [options]
    -h, --help      Show this message and exit.

Environment overrides (see the header of this script for details):
    DOTFILES  DOTFILES_SLUG  DOTFILES_BRANCH  DOTFILES_REF  DOTFILES_REPO
    NONINTERACTIVE  CI
EOS
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help) usage ;;
    *)
      warn "Unrecognized option: '$1'"
      usage 1
      ;;
  esac
done

# ------------------------------------------------------------ interactivity mode
# curl | bash leaves stdin as a pipe, so we must not block on a prompt there.
if [[ -z "${NONINTERACTIVE:-}" ]]; then
  if [[ -n "${CI:-}" ]]; then
    warn "Running non-interactively because \$CI is set."
    NONINTERACTIVE=1
  elif [[ ! -t 0 ]]; then
    warn "Running non-interactively because stdin is not a TTY."
    NONINTERACTIVE=1
  fi
fi

wait_for_user() {
  [[ -n "${NONINTERACTIVE:-}" ]] && return 0
  local c
  echo
  printf "Press %sRETURN%s/%sENTER%s to continue or any other key to abort: " \
    "$tty_bold" "$tty_reset" "$tty_bold" "$tty_reset"
  read -r -n 1 -s c || { echo; abort "Aborted."; }
  echo
  # Accept RETURN/ENTER; terminals send \r or \n (or nothing with -n 1).
  case "$c" in
    "" | $'\r' | $'\n') return 0 ;;
    *) abort "Aborted." ;;
  esac
}

# ------------------------------------------------------------------ retry helper
# retry <max> <command...> -- re-run with exponential backoff, abort when spent.
retry() {
  local -i max="$1"
  shift
  local -i attempt=1 delay=2
  while true; do
    if "$@"; then
      return 0
    fi
    if ((attempt >= max)); then
      abort "failed after ${max} attempts: $*"
    fi
    warn "attempt ${attempt}/${max} failed; retrying in ${delay}s..."
    sleep "$delay"
    delay=$((delay * 2))
    attempt=$((attempt + 1))
  done
}

# -------------------------------------------------------------- git availability
# True only when a *usable* git is present. On macOS a bare /usr/bin/git is just a
# Command Line Tools shim until the tools are installed -- invoking it would pop a
# GUI installer -- so there we additionally require `xcode-select -p` to succeed.
have_git() {
  command -v git >/dev/null 2>&1 || return 1
  [[ "$(uname -s)" == Darwin ]] && { xcode-select -p >/dev/null 2>&1 || return 1; }
  return 0
}

_download_tarball() {
  curl -fsSL "$1" | tar -xzf - --strip-components=1 -C "$2"
}

# Clone (or update) the repo into $DOTFILES and check out the resolved ref.
install_remote() {
  if have_git; then
    if [[ -d "$DOTFILES/.git" ]]; then
      ohai "Updating existing clone at $DOTFILES"
      retry 3 git -C "$DOTFILES" fetch --force --tags --prune origin
    else
      ohai "Cloning $DOTFILES_REPO into $DOTFILES"
      retry 3 git clone "$DOTFILES_REPO" "$DOTFILES"
      retry 3 git -C "$DOTFILES" fetch --force --tags origin
    fi

    # Resolve the ref: explicit override, else latest release tag, else branch.
    local ref pinned="" latest_tag
    if [[ -n "$DOTFILES_REF" ]]; then
      ref="$DOTFILES_REF"
      pinned=1
      ohai "Checking out pinned ref: $ref"
    else
      latest_tag="$(git -C "$DOTFILES" tag --list --sort='-version:refname' | head -n1)"
      if [[ -n "$latest_tag" ]]; then
        ref="$latest_tag"
        pinned=1
        ohai "Installing latest release: $ref"
      else
        ref="$DOTFILES_BRANCH"
        ohai "No release tags found -- tracking branch $ref"
      fi
    fi

    if [[ -n "$pinned" ]]; then
      # Pin onto a local 'stable' branch; tags/commits have no upstream.
      git -C "$DOTFILES" checkout --quiet --force -B stable "$ref" 2>/dev/null \
        || git -C "$DOTFILES" checkout --quiet --force -B stable "origin/$ref"
    elif git -C "$DOTFILES" show-ref --verify --quiet "refs/heads/$ref"; then
      # Existing local branch -- keep tracking upstream so `dotfiles update` works.
      git -C "$DOTFILES" checkout --quiet --force "$ref"
      retry 3 git -C "$DOTFILES" pull --ff-only --quiet
    else
      git -C "$DOTFILES" checkout --quiet --force -B "$ref" "origin/$ref"
    fi
  elif command -v curl >/dev/null 2>&1; then
    # git-less fallback: download a source tarball. Without git we cannot resolve
    # the latest tag, so this tracks DOTFILES_REF or the branch.
    local ref tarball
    ref="${DOTFILES_REF:-$DOTFILES_BRANCH}"
    tarball="https://github.com/$DOTFILES_SLUG/archive/$ref.tar.gz"
    warn "git unavailable -- downloading tarball ($ref); 'dotfiles update' will need git later"
    mkdir -p "$DOTFILES"
    retry 3 _download_tarball "$tarball" "$DOTFILES"
  else
    abort "need either git or curl to install remotely"
  fi
}

# ------------------------------------------------------------------ locate repo
# (a) install.sh runs from inside a checkout -> use it in place.
# (b) bootstrap via curl (no local file) -> fetch the repo into $DOTFILES.
__self="${BASH_SOURCE[0]:-}"
__self_dir=""
if [[ -n "$__self" ]]; then
  __self_dir="$(cd -P "$(dirname "$__self")" 2>/dev/null && pwd || true)"
fi

if [[ -n "$__self_dir" && -f "$__self_dir/bin/dotfiles" ]]; then
  MODE="local"
  DOTFILES="$__self_dir"
else
  MODE="bootstrap"
  DOTFILES="${DOTFILES:-$HOME/dotfiles}"
  DOTFILES_SLUG="${DOTFILES_SLUG:-beratiyilik/dotfiles}"
  DOTFILES_BRANCH="${DOTFILES_BRANCH:-main}"
  DOTFILES_REF="${DOTFILES_REF:-}"
  DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/$DOTFILES_SLUG.git}"
fi

# ------------------------------------------------------------- preview + confirm
ohai "This script will:"
if [[ "$MODE" == "local" ]]; then
  echo "  - Use the local checkout at $DOTFILES"
elif [[ -d "$DOTFILES/.git" ]]; then
  echo "  - Update the existing clone at $DOTFILES"
else
  echo "  - Install $DOTFILES_SLUG into $DOTFILES"
fi
echo "  - Symlink configs into \$HOME per .symlinks (existing files are backed up)"
echo "  - Run OS package setup and init hooks (dotfiles init)"
wait_for_user

# --------------------------------------------------------------------- install
if [[ "$MODE" == "bootstrap" ]]; then
  install_remote
fi
export DOTFILES

if [[ ! -f "$DOTFILES/bin/dotfiles" ]]; then
  abort "bin/dotfiles not found under $DOTFILES"
fi

chmod +x "$DOTFILES/bin/dotfiles" # bin/dotf is a symlink to dotfiles
export PATH="$DOTFILES/bin:$PATH"

if [[ ! -f "$DOTFILES/vars/local.env" ]]; then
  cp "$DOTFILES/vars/local.env.sample" "$DOTFILES/vars/local.env"
  ohai "Created vars/local.env from sample -- edit it to add your credentials."
fi

ohai "Running dotfiles init"
dotfiles init

ohai "Installation successful!"
echo
echo "Next steps:"
echo "  - Open a new shell, or run: source ~/.zshrc   (or ~/.bashrc)"
echo "  - Then 'dotfiles' / 'dotf' are on your PATH. Try: dotfiles doctor"
