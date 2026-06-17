# shellcheck shell=bash
# Sourced by .zshrc / .bashrc after functions.sh + aliases.sh.
#
# =============================================================================
# git.sh — git shell integration (Bash + Zsh)
#
# Thin git wrappers kept in shell (status display, log, guards). The AI git
# features (commit / branch / rebase) live in tools/git_ai and are exposed here
# only as aliases.
#
# Colour variables (COLOR_*, FG_*, STYLE_*) are optional; output degrades to
# plain text when they are unset.
# =============================================================================

# --------------------------------------------------------------------- GUARDS

# check if cwd is inside a git work tree
_is_git() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 && return 0
  printf "%bNot a git repository%b\n" "${COLOR_ERROR:-}" "${STYLE_RESET:-}" >&2
  return 1
}

# --------------------------------------------------------------------- STATUS

# current timestamp and user header
_get_timestamp_user() {
  printf "%b%s%b - %b%s%b\n" \
    "${FG_GRAY_MEDIUM:-}" "$(date '+%Y-%m-%d %H:%M:%S')" "${STYLE_RESET:-}" \
    "${STYLE_BOLD:-}" "$(id -un)" "${STYLE_RESET:-}"
}

# short or detailed working-tree status (aliases: gss / gsd)
_git_status() {
  _is_git || return 1

  local mode="short"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s | --short)    mode="short";    shift ;;
      -d | --detailed) mode="detailed"; shift ;;
      *)
        printf "%bInvalid option:%b %s\n" "${COLOR_ERROR:-}" "${STYLE_RESET:-}" "$1" >&2
        printf "Usage: _git_status [-s|--short] [-d|--detailed]\n" >&2
        return 1 ;;
    esac
  done

  _get_timestamp_user

  local repo_name branch
  repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --always 2>/dev/null)
  printf "Repository: %b%s%b  Branch: %b%s%b\n" \
    "${STYLE_BOLD:-}" "$repo_name" "${STYLE_RESET:-}" \
    "${STYLE_BOLD:-}" "$branch" "${STYLE_RESET:-}"

  if [[ "$mode" == "detailed" ]]; then
    local remote_branch ahead_behind
    remote_branch=$(git for-each-ref --format='%(upstream:short)' "$(git symbolic-ref -q HEAD)" 2>/dev/null)
    if [[ -n "$remote_branch" ]]; then
      if ahead_behind=$(git rev-list --left-right --count "$remote_branch...$branch" 2>/dev/null); then
        printf "Remote: %s [ahead %s | behind %s]\n" \
          "$remote_branch" \
          "$(printf '%s' "$ahead_behind" | awk '{print $2}')" \
          "$(printf '%s' "$ahead_behind" | awk '{print $1}')"
      fi
    else
      printf "Remote: %bno tracking branch%b\n" "${COLOR_WARNING:-}" "${STYLE_RESET:-}"
    fi

    local stash_count last_commit
    stash_count=$(git stash list 2>/dev/null | wc -l); stash_count="${stash_count// /}"
    [[ "$stash_count" -gt 0 ]] && printf "Stashed: %s\n" "$stash_count"
    last_commit=$(git log -1 --pretty=format:"%h - %s (%an, %ad)" --date=format:"%Y-%m-%d %H:%M" 2>/dev/null)
    [[ -n "$last_commit" ]] && printf "Last commit: %b%s%b\n" "${STYLE_BOLD:-}" "$last_commit" "${STYLE_RESET:-}"
  fi

  local staged unstaged untracked total
  staged=$(git diff --name-only --staged | wc -l);               staged="${staged// /}"
  unstaged=$(git diff --name-only | wc -l);                      unstaged="${unstaged// /}"
  untracked=$(git ls-files --others --exclude-standard | wc -l); untracked="${untracked// /}"
  total=$((staged + unstaged + untracked))

  if [[ "$total" -eq 0 ]]; then
    printf "%bWorking tree clean%b\n" "${COLOR_SUCCESS:-}" "${STYLE_RESET:-}"
    return 0
  fi

  if [[ "$mode" == "detailed" ]]; then
    [[ "$staged"    -gt 0 ]] && printf "  staged:    %s\n" "$staged"
    [[ "$unstaged"  -gt 0 ]] && printf "  unstaged:  %s\n" "$unstaged"
    [[ "$untracked" -gt 0 ]] && printf "  untracked: %s\n" "$untracked"
  else
    printf "%b%s file(s) changed%b\n" "${COLOR_WARNING:-}" "$total" "${STYLE_RESET:-}"
  fi
  git -c color.status=always status --short
}

# -------------------------------------------------------------------- ALIASES

alias is_git="_is_git"
alias gss="_git_status --short"
alias gsd="_git_status --detailed"
alias glf="git log --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --graph"

# AI git helpers (implemented in tools/git_ai, on PATH via $DOTFILES/tools)
alias ai_commit="git_ai commit"   # commit message for staged changes
alias ai_branch="git_ai branch"   # branch-name suggestion for the working tree
alias ai_rebase="git_ai rebase"   # interactive rebase with AI squash messages

## eof
