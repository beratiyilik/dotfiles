# shellcheck shell=bash
# $DOTFILES_DIR/lib/git_helpers.sh

# =============================================================================
# git_helpers.sh — git utility library (Bash + Zsh)
#
# DESCRIPTION
#   Provides git guard functions, enhanced status reporting, and AI-assisted
#   commit message generation via a local ollama model. Designed to be sourced
#   from .bashrc / .zshrc or from the _ai_rebase editor shim.
#
# PUBLIC FUNCTIONS
#   _is_git        check if cwd is inside a git work tree
#   _is_staged     check if there are staged changes
#   _git_status    short or detailed working tree status
#   _ai_commit     generate a commit message for staged changes
#   _ai_rebase     interactive rebase with AI-assisted squash messages
#   _ai_branch_name  generate a branch name suggestion for working-tree changes
#
# ALIASES
#   gss            _git_status --short
#   gsd            _git_status --detailed
#   glf            decorated graph log
#   is_git         _is_git
#   is_staged      _is_staged
#   ai_commit      _ai_commit
#   ai_rebase      _ai_rebase
#   ai_branch      _ai_branch_name
#
# ENVIRONMENT VARIABLES
#   DOTFILES_DIR      dotfiles root          (auto-detected by lib/env.sh)
#   AI_COMMIT_MODEL   ollama model name      (default: qwen2.5-coder:7b)
#   AI_COMMIT_URL     ollama endpoint        (default: http://localhost:11434/api/generate)
#   EDITOR            editor binary          (default: vi / nano in rebase shim)
#
#   Styling variables are optional; output degrades gracefully if unset.
#   See CONSTANTS section for the full list.
#
# DEPENDENCIES
#   git    all functions
#   curl   _ai_commit, _ai_rebase
#   jq     _ai_commit, _ai_rebase
#   ollama _ai_commit, _ai_rebase  (local, http://localhost:11434)
# =============================================================================

#############################################################################
# CONSTANTS
#############################################################################

# style
STYLE_RESET=${STYLE_RESET:-"\033[0m"}
STYLE_BOLD=${STYLE_BOLD:-"\033[1m"}

# base colors
FG_BLUE=${FG_BLUE:-"\033[38;5;33m"}
FG_CYAN=${FG_CYAN:-"\033[38;5;66m"}
FG_GREEN=${FG_GREEN:-"\033[38;5;76m"}
FG_MAGENTA=${FG_MAGENTA:-"\033[38;5;201m"}
FG_RED=${FG_RED:-"\033[38;5;196m"}
FG_WHITE=${FG_WHITE:-"\033[0;37m"}
FG_YELLOW=${FG_YELLOW:-"\033[38;5;220m"}

# extended colors
FG_GRAY_MEDIUM=${FG_GRAY_MEDIUM:-"\033[38;5;250m"}
FG_LIGHT_BLUE=${FG_LIGHT_BLUE:-"\033[38;5;81m"}
FG_LIGHT_GREEN=${FG_LIGHT_GREEN:-"\033[38;5;120m"}
FG_ORANGE=${FG_ORANGE:-"\033[38;5;214m"}
FG_PURPLE=${FG_PURPLE:-"\033[38;5;141m"}

# semantic colors
COLOR_ERROR=${COLOR_ERROR:-"${FG_RED}"}
COLOR_INFO=${COLOR_INFO:-"${FG_CYAN}"}
COLOR_SUCCESS=${COLOR_SUCCESS:-"${FG_GREEN}"}
COLOR_WARNING=${COLOR_WARNING:-"${FG_YELLOW}"}

# icons
ICON_BRANCH=${ICON_BRANCH:-""}
ICON_CHECK=${ICON_CHECK:-"✔"}
ICON_WARNING=${ICON_WARNING:-"⚠"}
ICON_REMOTE=${ICON_REMOTE:-"⇅"}
ICON_STASH=${ICON_STASH:-""}
ICON_STAGED=${ICON_STAGED:-"●"}
ICON_UNSTAGED=${ICON_UNSTAGED:-"✚"}
ICON_UNTRACKED=${ICON_UNTRACKED:-"…"}
ICON_CONFLICT=${ICON_CONFLICT:-"✖"}
ICON_CLOCK=${ICON_CLOCK:-""}
ICON_USER=${ICON_USER:-""}

# ai
_AI_COMMIT_MODEL="${AI_DEFAULT_SMALL_MODEL:-qwen2.5-coder:7b}"
_AI_COMMIT_API_URL="${AI_API_URL:-http://localhost:11434/api/generate}"
_GIT_COMMIT_MESSAGE_CONVENTION_PATH="$DOTFILES_DIR/docs/GIT_COMMIT_MESSAGE_CONVENTION.md"

#############################################################################
# GIT HELPERS
#############################################################################

# check if in git repository
_is_git() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf "%bNot a git repository%b\n" "$COLOR_ERROR" "$STYLE_RESET" >&2
    return 1
  fi
  return 0
}

# check if there are staged changes
_is_staged() {
  [[ -n "$(git diff --cached --stat)" ]] || {
    printf "%bNo staged changes to commit%b\n" "$COLOR_ERROR" "$STYLE_RESET" >&2
    return 1
  }
}

# display git status information
_git_status() {
  _git_status_usage() {
    printf "%b%s%b %b_git_status%b %b[-s|--short] [-d|--detailed]%b\n" \
      "$STYLE_BOLD" "Usage:" "$STYLE_RESET" \
      "$STYLE_BOLD" "$STYLE_RESET" \
      "$COLOR_WARNING" "$STYLE_RESET" >&2
  }

  # ensure current directory is a git repo before proceeding
  _is_git || return 1

  # default status display mode
  local mode="short"

  # parse command-line arguments for display mode
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s | --short)
        # short mode for minimal output
        mode="short"
        shift
        ;;
      -d | --detailed)
        # detailed mode for verbose status
        mode="detailed"
        shift
        ;;
      *)
        # invalid option provided
        printf "%bInvalid option:%b %b%s%b\n" \
          "$COLOR_ERROR" "$STYLE_RESET" "$COLOR_WARNING" "$1" "$STYLE_RESET" >&2
        _git_status_usage
        return 1
        ;;
    esac
  done

  # display timestamp and user info header
  _get_timestamp_user

  # get repository name
  local repo_name branch
  repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")
  printf "Git repository: %b%s%b\n" "$STYLE_BOLD" "$repo_name" "$STYLE_RESET"

  # get the current branch or tag name
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --always 2>/dev/null)
  # print current branch name
  printf "%b%s Branch:%b %b%b%s%b\n" \
    "$COLOR_INFO" "$ICON_BRANCH" "$STYLE_RESET" \
    "$STYLE_BOLD" "$COLOR_SUCCESS" "$branch" "$STYLE_RESET"

  # show upstream branch and stash info in detailed mode
  if [[ "$mode" == "detailed" ]]; then
    # get upstream tracking branch
    local remote_branch
    remote_branch=$(git for-each-ref --format='%(upstream:short)' "$(git symbolic-ref -q HEAD)")
    if [[ -n "$remote_branch" ]]; then
      # get ahead/behind commit counts
      local ahead_behind ahead behind
      if ahead_behind=$(git rev-list --left-right --count "$remote_branch...$branch" 2>/dev/null); then
        ahead=$(printf '%s' "$ahead_behind" | awk '{print $2}')
        behind=$(printf '%s' "$ahead_behind" | awk '{print $1}')
        printf "%b%s Remote:%b %b%s%b [%b↑%s%b|%b↓%s%b]\n" \
          "$COLOR_INFO" "$ICON_REMOTE" "$STYLE_RESET" \
          "$COLOR_SUCCESS" "$remote_branch" "$STYLE_RESET" \
          "$COLOR_SUCCESS" "$ahead" "$STYLE_RESET" \
          "$COLOR_ERROR" "$behind" "$STYLE_RESET"
      fi
    else
      # no upstream branch configured
      printf "%b%s Remote:%b %bNo tracking branch%b\n" \
        "$COLOR_INFO" "$ICON_REMOTE" "$STYLE_RESET" "$COLOR_WARNING" "$STYLE_RESET"
    fi

    # count number of stashed changes
    local stash_count
    stash_count=$(git stash list | wc -l)
    stash_count="${stash_count// /}"
    if [[ "$stash_count" -gt 0 ]]; then
      printf "%b%s Stashed:%b %b%s stash(es)%b\n" \
        "$COLOR_INFO" "$ICON_STASH" "$STYLE_RESET" \
        "$FG_LIGHT_BLUE" "$stash_count" "$STYLE_RESET"
    fi

    # last commit information
    local last_commit commit_author commit_date
    last_commit=$(git log -1 --pretty=format:"%h - %s" 2>/dev/null)
    commit_author=$(git log -1 --pretty=format:"%an" 2>/dev/null)
    commit_date=$(git log -1 --pretty=format:"%ad" --date=format:"%Y-%m-%d %H:%M:%S" 2>/dev/null)

    if [[ -n "$last_commit" ]]; then
      printf "%bLast commit:%b %b%s%b\n" \
        "$COLOR_INFO" "$STYLE_RESET" "$STYLE_BOLD" "$last_commit" "$STYLE_RESET"
      printf "By: %b%b%s%b on %b%s%b\n" \
        "$STYLE_BOLD" "$FG_LIGHT_GREEN" "$commit_author" "$STYLE_RESET" \
        "$FG_GRAY_MEDIUM" "$commit_date" "$STYLE_RESET"
    fi
  fi

  # count changes by type: staged, unstaged, untracked
  local staged_changes unstaged_changes untracked total_changes
  staged_changes=$(git diff --name-only --staged | wc -l)
  unstaged_changes=$(git diff --name-only | wc -l)
  untracked=$(git ls-files --others --exclude-standard | wc -l)
  staged_changes="${staged_changes// /}"
  unstaged_changes="${unstaged_changes// /}"
  untracked="${untracked// /}"
  total_changes=$((staged_changes + unstaged_changes + untracked))

  # display file changes summary based on selected mode
  if [[ "$mode" == "short" ]]; then
    if [[ "$total_changes" -eq 0 ]]; then
      # no changes found in short mode
      printf "%b%s Working tree clean%b\n" "$COLOR_SUCCESS" "$ICON_CHECK" "$STYLE_RESET"
    else
      # show summary of modified files in short mode
      printf "%b%s %s file(s) changed%b\n" "$COLOR_WARNING" "$ICON_WARNING" "$total_changes" "$STYLE_RESET"
      git -c color.status=always status --short
    fi
  else
    # detailed mode: show categorized change types
    printf "%bStatus:%b\n" "$COLOR_INFO" "$STYLE_RESET"
    if [[ "$total_changes" -eq 0 ]]; then
      printf "%b%s Working tree clean%b\n" "$COLOR_SUCCESS" "$ICON_CHECK" "$STYLE_RESET"
    else
      if [[ "$staged_changes" -gt 0 ]]; then
        printf "%b%s %s staged file(s)%b\n" "$FG_ORANGE" "$ICON_STAGED" "$staged_changes" "$STYLE_RESET"
      fi
      if [[ "$unstaged_changes" -gt 0 ]]; then
        printf "%b%s %s unstaged file(s)%b\n" "$FG_ORANGE" "$ICON_UNSTAGED" "$unstaged_changes" "$STYLE_RESET"
      fi
      if [[ "$untracked" -gt 0 ]]; then
        printf "%b%s %s untracked file(s)%b\n" "$FG_PURPLE" "$ICON_UNTRACKED" "$untracked" "$STYLE_RESET"
      fi

      # check for conflicts
      local conflict_files
      conflict_files=$(git diff --name-only --diff-filter=U | wc -l)
      conflict_files="${conflict_files// /}"
      if [[ "$conflict_files" -gt 0 ]]; then
        printf "%b%s %s conflict file(s)%b\n" "$COLOR_ERROR" "$ICON_CONFLICT" "$conflict_files" "$STYLE_RESET"
      fi

      # print list of changed files
      printf "%bChanged files:%b\n" "$COLOR_INFO" "$STYLE_RESET"
      git -c color.status=always status --short
    fi
  fi
}

#############################################################################
# DISPLAY
#############################################################################

# current timestamp and user information
_get_timestamp_user() {
  local timestamp username
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  username=$(id -un)
  printf "%b%s %s%b - %b%b%s %s%b\n" \
    "$FG_GRAY_MEDIUM" "$ICON_CLOCK" "$timestamp" "$STYLE_RESET" \
    "$STYLE_BOLD" "$FG_LIGHT_GREEN" "$ICON_USER" "$username" "$STYLE_RESET"
}

# global pid tracker for the git spinner background process
: "${_GIT_SPINNER_PID:=}"

# spinner definitions — only defined here if functions.sh was not sourced first;
# when sourced standalone (e.g. by _ai_rebase shim), these provide the implementation
if ! command -v _git_spinner_start >/dev/null 2>&1; then
  _git_spinner_start() {
    [[ -n "${ZSH_VERSION:-}" ]] && setopt NO_MONITOR 2>/dev/null || true
    local msg="${1:-Generating...}"
    local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local len=${#frames}
    (
      local i=0
      while true; do
        printf "\r%s %s" "${frames:$i:1}" "$msg"
        sleep 0.08
        i=$(( (i + 1) % len ))
      done
    ) 2>/dev/null &
    _GIT_SPINNER_PID=$!
    disown "$_GIT_SPINNER_PID" 2>/dev/null || true
  }

  _git_spinner_stop() {
    [[ -n "${_GIT_SPINNER_PID:-}" ]] || return 0
    kill "$_GIT_SPINNER_PID" 2>/dev/null || true
    _GIT_SPINNER_PID=""
    printf "\r                    \r"
  }
fi

#############################################################################
# AI — shared helpers
#############################################################################

# verify required external commands are available
# usage: __git_helpers_check_deps
__git_helpers_check_deps() {
  local missing=""
  for cmd in git curl jq; do
    command -v "$cmd" >/dev/null 2>&1 || missing="${missing}  ${cmd}\n"
  done
  [[ -z "$missing" ]] || { printf "error: missing dependencies:\n%b" "$missing" >&2; return 1; }
}

# verify convention file exists at the given path
# usage: __git_helpers_check_convention <path>
__git_helpers_check_convention() {
  local path="$1"
  [[ -f "$path" ]] || {
    printf "error: convention file not found: %s\n" "$path" >&2; return 1
  }
}

# load convention file, dropping the Decision Flow section and everything after
# usage: __git_helpers_load_convention <path>
__git_helpers_load_convention() {
  awk '/^## Decision Flow/ { exit } { print }' "$1"
}

# build the staged diff: stat header + body (lock/minified files excluded, capped at max_bytes)
# usage: __git_helpers_build_diff <max_bytes>
__git_helpers_build_diff() {
  local max_bytes="${1:-24000}"
  local stat body
  stat=$(git diff --cached --stat)
  body=$(git diff --cached -- . \
           ':(exclude)*.lock' \
           ':(exclude)*-lock.*' \
           ':(exclude)*.min.*' \
         | head -c "$max_bytes")
  printf "%s\n%s" "$stat" "$body"
}

# build the working-tree diff (unstaged + untracked, capped at max_bytes)
# usage: __git_helpers_build_workdiff <max_bytes>
__git_helpers_build_workdiff() {
  local max_bytes="${1:-24000}"
  local stat unstaged untracked_list untracked_content body

  stat=$(git diff --stat)

  unstaged=$(git diff -- . \
               ':(exclude)*.lock' \
               ':(exclude)*-lock.*' \
               ':(exclude)*.min.*')

  untracked_list=$(git ls-files --others --exclude-standard)

  # include content of untracked files (skip binaries and lock/minified files)
  untracked_content=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in
      *.lock | *-lock.* | *.min.*) continue ;;
    esac
    if git check-attr -- "$f" 2>/dev/null | grep -q 'binary: set'; then
      untracked_content+=$'\n'"--- new file (binary, skipped): $f ---"
      continue
    fi
    untracked_content+=$(printf '\n--- new file: %s ---\n%s\n' "$f" "$(head -c 2000 "$f")")
  done <<< "$untracked_list"

  body=$(printf "%s\n\n--- untracked files ---\n%s\n--- unstaged diff ---\n%s" \
           "$stat" "$untracked_content" "$unstaged")

  # if over the byte limit, truncate at the last full diff hunk boundary
  if (( $(printf '%s' "$body" | wc -c) > max_bytes )); then
    body=$(printf '%s' "$body" | head -c "$max_bytes" \
             | awk 'BEGIN{last=0} {lines[NR]=$0; if ($0 ~ /^diff --git/) last=NR} END{for(i=1;i<(last>1?last:NR+1);i++) print lines[i]}')
    body+=$'\n\n[... truncated to fit context window ...]'
  fi

  printf '%s' "$body"
}

# build the ollama JSON payload
# usage: __git_helpers_build_payload <model> <system_prompt> <user_prompt>
__git_helpers_build_payload() {
  local model="$1"
  local system_prompt="$2"
  local user_prompt="$3"
  jq -n \
    --arg model  "$model" \
    --arg system "$system_prompt" \
    --arg prompt "$user_prompt" \
    '{
      model: $model,
      system: $system,
      prompt: $prompt,
      stream: false,
      options: { temperature: 0, num_predict: 300, num_ctx: 32768 }
    }'
}

# send payload to ollama endpoint and print the response text to stdout
# returns non-zero on transport error, non-200 HTTP, or model error field
# usage: __git_helpers_request <url> <payload>
__git_helpers_request() {
  local url="$1"
  local payload="$2"
  local resp code body err
  resp=$(curl -s -w '\n%{http_code}' "$url" -d "$payload") || {
    printf "error: request to %s failed\n" "$url" >&2; return 1
  }
  code="${resp##*$'\n'}"
  body="${resp%$'\n'*}"
  [[ "$code" == "200" ]] || {
    printf "error: HTTP %s from model endpoint\n" "$code" >&2; return 1
  }
  err=$(printf '%s' "$body" | jq -r '.error // empty')
  [[ -z "$err" ]] || { printf "error: model: %s\n" "$err" >&2; return 1; }
  printf '%s' "$body" | jq -r '.response'
}

# strip markdown fences, language tags, and leading preamble the model may emit
# usage: __git_helpers_clean_msg <msg>
__git_helpers_clean_msg() {
  printf '%s' "$1" \
    | sed -E \
        -e '/^[[:space:]]*```[[:alnum:]_+.-]*[[:space:]]*$/d' \
        -e 's/```//g' \
        -e '1s/^[[:space:]]*(plaintext|text|txt|markdown|md|bash|sh|shell|console)([[:space:]]+|$)//' \
        -e '/^[Hh]ere.s .*commit message/d' \
    | awk '
        { lines[NR] = $0 }
        END {
          s = 1;  while (s <= NR && lines[s] ~ /^[[:space:]]*$/) s++
          e = NR; while (e >= 1  && lines[e] ~ /^[[:space:]]*$/) e--
          for (i = s; i <= e; i++) print lines[i]
        }'
}

#############################################################################
# AI
#############################################################################

_ai_commit() {
  _is_git                                               || return 1
  __git_helpers_check_deps                              || return 1
  _is_staged                                            || return 1
  __git_helpers_check_convention "$_GIT_COMMIT_MESSAGE_CONVENTION_PATH" || return 1

  local convention diff system_prompt payload msg
  convention=$(__git_helpers_load_convention "$_GIT_COMMIT_MESSAGE_CONVENTION_PATH")
  diff=$(__git_helpers_build_diff)

  system_prompt="You are a git commit message generator. Follow this convention:

${convention}

Generate ONE commit message for the diff the user provides.
Output ONLY the raw commit message text — no code blocks, no backticks, no markdown, no preamble or explanation."

  payload=$(__git_helpers_build_payload "$_AI_COMMIT_MODEL" "$system_prompt" "Diff:
${diff}")

  trap '_git_spinner_stop; trap - INT TERM' INT TERM
  _git_spinner_start "Generating commit message..."
  msg=$(__git_helpers_request "$_AI_COMMIT_API_URL" "$payload")
  local rc=$?
  _git_spinner_stop
  trap - INT TERM
  [[ "$rc" -eq 0 ]] || return 1

  msg=$(__git_helpers_clean_msg "$msg")
  { [[ -z "$msg" ]] || [[ "$msg" == "null" ]]; } && {
    printf "error: empty response from model\n" >&2; return 1
  }

  git commit -e -m "$msg"
}

_ai_squash_commit() {
  local _commit_file="$1"

  # first phase: rebase todo file (pick/squash selection) — skip AI, open editor directly
  case "$_commit_file" in
    *"rebase-merge/git-rebase-todo"* | *"rebase-todo"*)
      "${EDITOR:-vi}" "$_commit_file" </dev/tty >/dev/tty
      return
      ;;
  esac

  # second phase: commit message file — extract non-comment, non-empty lines as squashed messages
  local existing_msgs
  existing_msgs=$(grep -v '^\s*#' "$_commit_file" | grep -v '^\s*$')

  if [[ -z "$existing_msgs" ]]; then
    "${EDITOR:-vi}" "$_commit_file" </dev/tty >/dev/tty
    return
  fi

  local convention=""
  if __git_helpers_check_convention "$_GIT_COMMIT_MESSAGE_CONVENTION_PATH" 2>/dev/null; then
    convention=$(__git_helpers_load_convention "$_GIT_COMMIT_MESSAGE_CONVENTION_PATH")
  fi

  local system_prompt="You are a git commit message generator. Follow this convention:

${convention}

Generate ONE squash commit message that summarizes all of the messages the user provides.
Output ONLY the raw commit message text — no code blocks, no backticks, no markdown, no preamble or explanation."

  local payload
  payload=$(__git_helpers_build_payload "$_AI_COMMIT_MODEL" "$system_prompt" \
    "These are the individual commit messages being squashed:

${existing_msgs}")

  local ai_msg
  _git_spinner_start "Generating squash commit message..."
  ai_msg=$(__git_helpers_request "$_AI_COMMIT_API_URL" "$payload")
  local rc=$?
  _git_spinner_stop

  if [[ "$rc" -ne 0 ]]; then
    printf "warning: model request failed — opening editor directly\n" >&2
    "${EDITOR:-vi}" "$_commit_file" </dev/tty >/dev/tty
    return
  fi

  ai_msg=$(__git_helpers_clean_msg "$ai_msg")

  if [[ -n "$ai_msg" ]] && [[ "$ai_msg" != "null" ]]; then
    local existing_content
    existing_content=$(cat "$_commit_file")
    printf "%s\n\n%s\n" "$ai_msg" "$existing_content" > "$_commit_file"
  fi

  # open editor for user to review and finalize the message
  # explicit tty redirect needed since this runs in a git subshell without terminal access
  "${EDITOR:-vi}" "$_commit_file" </dev/tty >/dev/tty
}

_ai_rebase() {
  local _user
  _user=$(id -un)
  local _dir="${TMPDIR:-/tmp}/${_user}/ai_rebase"
  mkdir -p "$_dir"

  # separate declaration from assignment to preserve exit code
  local _id
  _id="$(date +%Y%m%d%H%M%S)_${RANDOM}"
  local _shim="${_dir}/squash_editor_${_id}.sh"
  local _seq_editor="${_dir}/sequence_editor_${_id}.sh"

  # quote the path to git_helpers.sh to handle spaces; safe against single-quote injection
  # because $HOME is set by the shell and is not user-controlled input
  local _helpers_path
  printf -v _helpers_path '%q' "$DOTFILES_DIR/lib/git_helpers.sh"

  # detect shell for the shim — fall back to zsh if SHELL is unset
  local _shell="${SHELL:-zsh}"

  # shim: GIT_EDITOR runs in a subshell — functions are not inherited.
  # script(1) allocates a pseudo-tty so the editor can attach to the terminal.
  # script syntax differs between macOS (BSD) and Linux (GNU):
  #   BSD:  script -q /dev/null <cmd> [args...]
  #   GNU:  script -q /dev/null -c "<cmd> args"
  # We detect at shim execution time so the shim is portable across machines.
  cat > "$_shim" <<EOF
#!/bin/sh
if script --version 2>/dev/null | grep -q GNU; then
  script -q /dev/null -c "${_shell} -c 'source ${_helpers_path}; _ai_squash_commit \"\$1\"' _ \"\$1\""
else
  script -q /dev/null ${_shell} -c "source ${_helpers_path}; _ai_squash_commit \"\$1\"" _ "\$1"
fi
EOF

  # sequence editor: runs on the rebase todo file before the editor opens.
  # - strips update-ref lines to prevent unintended branch pointer updates.
  # - warns if exec/reset/merge lines are present, as they may cause side effects.
  # - sed -i syntax differs between macOS (BSD) and Linux (GNU), detected at runtime.
  # - single-quoted EOF so $1 is not expanded here, but at runtime by git.
  cat > "$_seq_editor" <<'EOF'
#!/bin/sh
if sed --version 2>/dev/null | grep -q GNU; then
  sed -i "/^update-ref/d" "$1"
else
  sed -i "" "/^update-ref/d" "$1"
fi
if grep -q "^exec\|^reset\|^merge" "$1"; then
  printf "warning: todo contains exec/reset/merge lines, review carefully\n" >&2
fi
exec "${EDITOR:-nano}" "$1"
EOF

  chmod +x "$_shim" "$_seq_editor"

  _ai_rebase_cleanup() {
    rm -f "$_shim" "$_seq_editor"
    rmdir "$_dir" 2>/dev/null || true
    trap - INT TERM
    unset -f _ai_rebase_cleanup
  }
  trap '_ai_rebase_cleanup' INT TERM

  # override both editors for this rebase only.
  # advice.waitingForEditor=false suppresses the "Waiting for your editor" hint.
  GIT_SEQUENCE_EDITOR="$_seq_editor" GIT_EDITOR="$_shim" \
    git -c advice.waitingForEditor=false rebase -i "$@"
  local _rc=$?

  _ai_rebase_cleanup
  return $_rc
}

# generate a branch name suggestion based on current working-tree changes
_ai_branch_name() {
  _is_git                  || return 1
  __git_helpers_check_deps || return 1

  local diff system_prompt payload name
  diff=$(__git_helpers_build_workdiff)

  [[ -n "$diff" ]] || {
    printf "error: no changes found in working tree\n" >&2; return 1
  }

  # branch naming uses a static format spec rather than the commit convention file —
  # embedding the full commit convention (with its <type>(<scope>): <description> format)
  # causes the model to produce commit-style subject lines instead of branch names
  system_prompt="You are a git branch name generator.

Valid types: feat, fix, refactor, perf, style, test, docs, build, ops, chore, revert.

STRICT OUTPUT FORMAT: <type>/<short-kebab-case-description>
Examples of valid output:
feat/add-tmux-config
fix/handle-null-input
refactor/extract-token-reader

Rules:
- lowercase only
- words separated by hyphens
- no colons, no scopes, no spaces, no parentheses, no slashes other than the one after <type>
- description max 4-5 words

Based on the diff the user provides, suggest ONE branch name in this exact format.
Output ONLY the branch name — no explanation, no quotes, no backticks, no markdown."

  payload=$(__git_helpers_build_payload "$_AI_COMMIT_MODEL" "$system_prompt" "Diff:
${diff}")

  trap '_git_spinner_stop; trap - INT TERM' INT TERM
  _git_spinner_start "Suggesting branch name..."
  name=$(__git_helpers_request "$_AI_COMMIT_API_URL" "$payload")
  local rc=$?
  _git_spinner_stop
  trap - INT TERM
  [[ "$rc" -eq 0 ]] || return 1

  name=$(__git_helpers_clean_msg "$name")
  { [[ -z "$name" ]] || [[ "$name" == "null" ]]; } && {
    printf "error: empty response from model\n" >&2; return 1
  }

  printf "%bSuggested branch name:%b %b%s%b\n" \
    "$COLOR_INFO" "$STYLE_RESET" "$STYLE_BOLD$COLOR_SUCCESS" "$name" "$STYLE_RESET"
}

#############################################################################
# ALIASES
#############################################################################

# core git aliases
# alias g="git"
# alias ga="git add"
# alias gc="git commit -m"

# status and diff
# alias gs="git status"
alias gss="_git_status --short"
alias gsd="_git_status --detailed"
# alias gd="git diff"
# alias gds="git diff --staged"

# branches and remote
# alias gp="git push"
# alias gl="git pull"
# alias gb="git branch"
# alias gco="git checkout"

# logs
# alias glog="git log --oneline --decorate --graph"
# alias gloga="git log --oneline --decorate --graph --all"
# alias gls="git log --stat"
# alias glp="git log -p"
alias glf="git log --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --graph"

# cleanup & reset
# alias gclean="git clean -fd"            # remove untracked files and directories
# alias greset="git reset --hard"         # hard reset to head
# alias gundo="git reset --soft head~1"   # undo last commit, keep changes

# internal functions
alias is_git="_is_git"
alias ai_commit="_ai_commit"
alias ai_rebase="_ai_rebase"
alias ai_branch="_ai_branch_name"

# eof