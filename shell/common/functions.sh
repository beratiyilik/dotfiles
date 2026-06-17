# shellcheck shell=bash
# Sourced by .zshrc / .bashrc via $SHELL_FUNCTIONS_PATH (set in exports.sh).
#
# =============================================================================
# functions.sh — shell utility library (Bash + Zsh)
#
# ENVIRONMENT VARIABLES
#   Required:
#     LONG_DATETIME_FORMAT   strftime format for full datetime display  (e.g. "%Y-%m-%d %H:%M:%S %Z")
#     DATE_SUFFIX_FORMAT     strftime format for date-only suffixes      (e.g. "%Y%m%d")
#     DATETIME_SUFFIX_FORMAT strftime format for datetime suffixes       (e.g. "%Y%m%d%H%M%S")
#     TIME_SUFFIX_FORMAT     strftime format for time-only suffixes      (e.g. "%H%M%S")
#     BREW_DIR               Homebrew prefix                             (e.g. "/opt/homebrew")
#
#   Styling (optional - output degrades gracefully if unset):
#     COLOR_INFO    COLOR_ERROR
#     FG_RED        FG_GREEN    FG_YELLOW    FG_BLUE
#     STYLE_BOLD    STYLE_RESET
#
# DEPENDENCIES
#   coreutils   date, basename, dirname, tr, head, sleep, uname, mktemp
#   procps      ps, kill, xargs
#   lsof        _fzf_kill_ports, _display_path_entries (port/process inspection)
#   fzf         _fzf_kill_ports, _fzf_search, _fzf_history, _fzf_kill
#   bat         _fzf_search (file preview in fzf)
#   nano        _fzf_search (editor)
#   ncdu        _disk_usage (optional; falls back to du)
#   jq          _load_github_env, _load_npm_env, _load_aws_env
#   op          _load_github_env, _load_npm_env, _load_aws_env (1Password CLI)
#   osascript   _trm_new_window (macOS only)
# =============================================================================

# ---------------------------------------------------------------- DATE / TIME

# returns the current date and time
_now() {
    date +"$LONG_DATETIME_FORMAT"
}

# returns the current date and time in UTC
_utc() {
    TZ=UTC date +"$LONG_DATETIME_FORMAT"
}

# returns the current timestamp in seconds
_get_timestamp() {
    date +%s
}

# YYYYMMDD
_get_date_as_suffix() {
    date +"$DATE_SUFFIX_FORMAT"
}

# HHMMSS
_get_time_as_suffix() {
    date +"$TIME_SUFFIX_FORMAT"
}

# YYYYMMDDHHMMSS
_get_datetime_as_suffix() {
    date +"$DATETIME_SUFFIX_FORMAT"
}

# show current time in different timezones
_timezones() {
    local -r now="$(_get_timestamp)"

    _timezones_show_time() {
        local tz="$1" label="$2" emoji="$3" formatted=""

        # portable epoch formatting: GNU 'date' vs BSD/macOS 'date'
        if date -u -d "@0" +%s >/dev/null 2>&1; then
            # GNU coreutils
            formatted=$(TZ="$tz" LC_TIME=C date -d "@$now" +"$LONG_DATETIME_FORMAT")
        else
            # BSD/macOS
            formatted=$(TZ="$tz" LC_TIME=C date -r "$now" +"$LONG_DATETIME_FORMAT")
        fi

        printf "%s  %b%-14s%b %s\n" \
            "$emoji" "${COLOR_INFO-}" "${label}:" "${STYLE_RESET-}" "$formatted"
    }

    _timezones_show_time "UTC"                  "UTC"           "🌍"
    _timezones_show_time "America/Los_Angeles"  "San Francisco" "🇺🇸"
    _timezones_show_time "Europe/Istanbul"      "Istanbul"      "🇹🇷"
    _timezones_show_time "Europe/London"        "London"        "🇬🇧"
}

# ----------------------------------------------------------------- OS / SHELL

detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        *)      echo "unknown" ;;
    esac
}

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

is_macos() { [[ "$(detect_os)" == macos ]]; }
is_linux() { [[ "$(detect_os)" == linux ]]; }
is_arm64() { [[ "$(uname -m)" == arm64 ]]; }

is_bash() { [[ "$(detect_shell)" == bash ]]; }
is_zsh()  { [[ "$(detect_shell)" == zsh ]]; }

# switches the current shell to a specified shell type
_switch_to_bash() {
    _switch_to_bash_usage() {
        printf "usage: _switch_to_bash [bash|bash5|zsh] [-l|--login]\n" >&2
    }

    local target_shell="$1"
    local login="${2:-}"
    local is_login=0
    [[ "$login" == "-l" || "$login" == "--login" ]] && is_login=1
    local SHELL_PATH=""

    case "$target_shell" in
        bash)
            SHELL_PATH="/bin/bash"
            ;;
        bash5)
            SHELL_PATH="$BREW_DIR/bin/bash"
            ;;
        zsh)
            SHELL_PATH="/bin/zsh"
            ;;
        *)
            printf "Error: Unknown shell type: %s. Valid options are: bash, bash5, zsh\n" "$target_shell" >&2
            _switch_to_bash_usage
            return 1
            ;;
    esac

    if [[ ! -x "$SHELL_PATH" ]]; then
        printf "Error: %s is not installed or not executable.\n" "$SHELL_PATH" >&2
        return 1
    fi

    if [[ "$_SWITCHED_SHELL_PATH" == "$SHELL_PATH" ]]; then
        printf "Already using %s\n" "$SHELL_PATH"
        return 0
    fi

    printf "Switching from %s to %s%s\n" "${_SWITCHED_SHELL_PATH:-$SHELL}" "$SHELL_PATH" "$( [[ $is_login -eq 1 ]] && echo " (login shell)" )"

    export _SWITCHED_SHELL_PATH="$SHELL_PATH"

    if [[ $is_login -eq 1 ]]; then
        exec "$SHELL_PATH" --login
    else
        exec "$SHELL_PATH"
    fi
}

# check if a command exists in the system
# returns: 0=found, 1=not found, 2=usage error
_has_cmd() {
    [[ $# -eq 1 && -n "$1" ]] || return 2
    if command -v -- "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# check if a command is available and display a warning if not
_check_dependencies() {
    _check_dependencies_usage() {
        printf "usage: _check_dependencies [true|false] <tool1> [tool2 ...]\n" >&2
    }

    _check_dependencies_print_missing_tool() {
        local _tool="$1"
        printf "  %b✗%b %b%s%b is not installed\n" "$FG_YELLOW" "$STYLE_RESET" "$FG_BLUE" "$_tool" "$STYLE_RESET"
        printf "    %bNote:%b Install '%s' via your package manager.\n" "$FG_GREEN" "$STYLE_RESET" "$_tool"
    }

    local _should_exit=true

    case "$1" in
        true | false)
            _should_exit="$1"
            shift
            ;;
    esac

    if [[ "$#" -eq 0 ]]; then
        printf "%bWarning:%b No tools specified. Provide at least one.\n" "$FG_YELLOW" "$STYLE_RESET"
        _check_dependencies_usage
        return 0
    fi

    local _missing_count=0
    local _tool
    local _total_tools="$#"

    for _tool in "$@"; do
        if ! _has_cmd "$_tool"; then
            _check_dependencies_print_missing_tool "$_tool"
            _missing_count=$((_missing_count + 1))
        fi
    done

    if [[ "$_missing_count" -gt 0 ]]; then
        printf "\n%bDependency Check Failed:%b %d of %d required tools are missing.\n" "$FG_RED" "$STYLE_RESET" "$_missing_count" "$_total_tools"
        if [[ "$_should_exit" == "true" ]]; then
            printf "\n%bExiting:%b Required tools missing. Install them and retry.\n" "$FG_RED" "$STYLE_RESET"
            exit 1
        else
            return 1
        fi
    fi

    return 0
}

# ----------------------------------------------------------------------- FILE

# safe source/include another file
_safe_source() {
    local file_path="$1"
    local use_builtin="${2:-false}"
    local result

    if [[ -z "$file_path" ]]; then
        printf "Error: No file path provided\n" >&2
        return 1
    fi

    if [[ ! -f "$file_path" ]]; then
        printf "Error: File not found: %s\n" "$file_path" >&2
        return 1
    fi

    if [[ "$use_builtin" == "true" ]]; then
        if (builtin source /dev/null 2>/dev/null) >/dev/null 2>&1; then
            # shellcheck disable=SC3043,SC3045
            builtin source "$file_path"
            result=$?
            if [[ $result -eq 0 ]]; then
                printf "Successfully sourced (builtin): %s\n" "$file_path"
            else
                printf "Error: Failed to source (builtin): %s\n" "$file_path" >&2
            fi
            return $result
        else
            printf "Warning: 'builtin source' not supported. Falling back to '.'\n" >&2
        fi
    fi

    # POSIX-compatible fallback using dot (.)
    # shellcheck source=/dev/null
    . "$file_path"
    result=$?

    if [[ $result -eq 0 ]]; then
        printf "Successfully sourced: %s\n" "$file_path"
    else
        printf "Error: Failed to source: %s\n" "$file_path" >&2
    fi

    return $result
}

# mkdir -p PATH then cd into it (physical path), safely.
# Usage: _mkcd <path>
_mkcd() {
    _mkcd_usage() {
        printf 'usage: _mkcd <path>\n' >&2
    }

    if [[ "$#" -ne 1 || -z "$1" ]]; then
        _mkcd_usage
        return 2
    fi

    mkdir -p -- "$1" || { printf 'mkdir failed: %s\n' "$1" >&2; return 1; }
    cd -P -- "$1"    || { printf 'cd failed: %s\n'    "$1" >&2; return 1; }
}

# shows interactive disk usage for the current directory
_disk_usage() {
    local target="${1:-.}"
    if command -v ncdu >/dev/null 2>&1; then
        ncdu "$target"
    else
        du -h -d 1 "$target" 2>/dev/null | sort -hr
    fi
}

# generate a unique ID based on the current timestamp and process ID, for temporary file naming or similar purposes
_tspid() {
    printf '%s_%s' "$(date +"%Y%m%d%H%M%S")" "$$"
}

_pwd() {
  if [[ "$1" == "-o" ]]; then
    command pwd
    return
  fi
  local raw
  raw=$(command pwd)
  if [[ "$1" != "-b" && "$1" != "-p" ]]; then
    printf '%s\n' "$raw"
    return
  fi
  local path="$raw"
  # display literal $HOME instead of the expanded home path.
  if [[ "$path" == "$HOME"* ]]; then
    path="\$HOME${path#"$HOME"}"
  fi

  local color=1
  [[ "$1" == "-p" ]] && color=0

  local RESET='' DIM_BLUE='' BOLD_BLUE=''
  if (( color )); then
    RESET=$'\033[0m'
    DIM_BLUE=$'\033[2;38;5;39m'
    BOLD_BLUE=$'\033[1;38;5;39m'
  fi

  local -a parts=()
  local seg
  while IFS= read -r -d '/' seg; do
    [[ -n "$seg" ]] && parts+=("$seg")
  done <<< "${path}/"
  local total=${#parts[@]}
  # root or empty: nothing to color, emit a single slash.
  if (( total == 0 )); then
    printf '%s/%s\n' "$BOLD_BLUE" "$RESET"
    return
  fi

  local output=""
  # absolute path that isn't rewritten to $HOME: restore the leading slash.
  [[ "$path" == /* ]] && output="${DIM_BLUE}/${RESET}"
  local idx=0
  for seg in "${parts[@]}"; do
    idx=$(( idx + 1 ))
    local from_end=$(( total - idx + 1 ))
    if (( from_end % 2 == 1 )); then
      output+="${BOLD_BLUE}${seg}${RESET}"
    else
      output+="${DIM_BLUE}${seg}${RESET}"
    fi
    (( idx < total )) && output+="${DIM_BLUE}/${RESET}"
  done
  printf '%s\n' "$output"
}

# -------------------------------------------------------------------- PROCESS

# kills processes listening on specified ports, with validation, reporting, and escalation
_fzf_kill_ports() {
  local ports=("$@")

  # no args: interactively select from active listening ports via fzf
  if [[ ${#ports[@]} -eq 0 ]]; then
    local selected
    selected=$(lsof -iTCP -iUDP -nP 2>/dev/null | awk 'NR>1 && /LISTEN/ {print $9, $1, $2}' | sort -u | fzf -m --prompt="Kill port: " --preview='' | awk '{print $1}' | command grep -oE ':[0-9]+' | tr -d ':' | sort -u)
    [[ -z "$selected" ]] && return 0
    if [[ -n "${ZSH_VERSION:-}" ]]; then
      # shellcheck disable=SC2206
      ports=("${(f)selected}")
    else
      IFS=$'\n' read -r -a ports <<< "$selected"
    fi
    [[ -n "${ZSH_VERSION:-}" ]] && print -z "_fzf_kill_ports ${ports[*]}"
    return 0
  fi

  for port in "${ports[@]}"; do
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
      printf "_fzf_kill_ports: '%s' is not a valid port number (1-65535)\n" "$port"
      continue
    fi

    local pids
    pids=$(lsof -i :"$port" -t 2>/dev/null | sort -u)
    if [[ -z "$pids" ]]; then
      printf "port %s: no processes found\n" "$port"
      continue
    fi

    printf "port %s: found processes:\n" "$port"
    printf '%s\n' "$pids" | while read -r pid; do
      command ps -p "$pid" -o pid=,user=,command= 2>/dev/null | awk '{printf "  PID=%-6s USER=%-10s CMD=%s\n", $1, $2, substr($0, index($0,$3))}'
    done

    printf "port %s: sending SIGTERM...\n" "$port"
    printf '%s\n' "$pids" | xargs kill 2>/dev/null
    sleep 0.3

    local remaining
    remaining=$(lsof -i :"$port" -t 2>/dev/null | sort -u)
    if [[ -n "$remaining" ]]; then
      printf "port %s: process(es) still alive, sending SIGKILL...\n" "$port"
      printf '%s\n' "$remaining" | xargs kill -9 2>/dev/null
      sleep 0.1
    fi

    if [[ -z "$(lsof -i :"$port" -t 2>/dev/null)" ]]; then
      printf "port %s: done\n" "$port"
    else
      printf "port %s: failed to kill - may need elevated privileges\n" "$port"
    fi
  done
}

# ---------------------------------------------------------------- ENVIRONMENT

# displays the current PATH entries in a formatted way
_display_path_entries() {
    local _filter="${1:-all}"  # options: all | valid | missing
    local _format="${2:-text}" # options: text | csv | json
    local _json_entries=""
    local _seen_paths=()
    local _tmp_dir="/tmp/_display_path_entries"
    local _tmp_csv

    _display_path_entries_print_text() {
        local _entry_status="$1"
        local _path="$2"
        local _is_dup="$3"
        local _icon="" _color="" _note=""

        [[ -z "$_path" ]] && { printf "Error: No path provided\n" >&2; return; }

        case "$_entry_status" in
            valid)
                _icon="✓"
                _color="$FG_GREEN"
                ;;
            missing)
                _icon="✗"
                _color="$FG_RED"
                _note=" ${FG_RED}(not found)${STYLE_RESET}"
                ;;
            *)
                return 1
                ;;
        esac

        [[ -n "$_is_dup" ]] && _note="${_note} ${FG_YELLOW}(duplicate entry)${STYLE_RESET}"
        printf "   %b%s%b %s%b\n" "$_color" "$_icon" "$STYLE_RESET" "$_path" "$_note"
    }

    _display_path_entries_append_csv() {
        printf '"%s","%s","%s"\n' "$2" "$1" "$3" >>"$_tmp_csv"
    }

    _display_path_entries_append_json() {
        _json_entries="${_json_entries}{\"status\":\"$1\",\"path\":\"$2\",\"note\":\"$3\"},"
    }

    # check if a value exists in an array
    # usage: _display_path_entries_in_array needle "${array[@]}"
    _display_path_entries_in_array() {
        local needle="$1"; shift
        local item
        for item in "$@"; do
            [[ "$item" == "$needle" ]] && return 0
        done
        return 1
    }

    [[ -n "$PATH" ]] || return

    mkdir -p "$_tmp_dir"
    _tmp_csv=$(mktemp "${_tmp_dir}/path_entries_$(date +%s)_XXXX.csv")
    trap 'rm -f "$_tmp_csv"' EXIT

    printf '%-22s\n' "PATH entries:" >&2

    while IFS= read -r path_entry; do
        [[ -n "$path_entry" ]] || continue

        local is_dup=""
        if _display_path_entries_in_array "$path_entry" "${_seen_paths[@]}"; then
            is_dup="duplicate"
        fi
        _seen_paths+=("$path_entry")

        if [[ -d "$path_entry" ]]; then
            [[ "$_filter" == "missing" ]] && continue
            [[ "$_format" == "text" ]] && _display_path_entries_print_text valid   "$path_entry" "$is_dup"
            [[ "$_format" == "csv"  ]] && _display_path_entries_append_csv  valid   "$path_entry" "$is_dup"
            [[ "$_format" == "json" ]] && _display_path_entries_append_json valid   "$path_entry" "$is_dup"
        else
            [[ "$_filter" == "valid" ]] && continue
            [[ "$_format" == "text" ]] && _display_path_entries_print_text missing "$path_entry" "$is_dup"
            [[ "$_format" == "csv"  ]] && _display_path_entries_append_csv  missing "$path_entry" "$is_dup"
            [[ "$_format" == "json" ]] && _display_path_entries_append_json missing "$path_entry" "$is_dup"
        fi
    done < <(printf '%s' "$PATH" | tr ':' '\n')

    if [[ "$_format" == "json" ]]; then
        printf '[%s]\n' "${_json_entries%,}"
    elif [[ "$_format" == "csv" ]]; then
        printf '"status","path","note"\n'
        cat "$_tmp_csv"
    fi
}

_fzf_variable_set() {
  local tmpdir name sel current newval prefix=""
  local -a names

  # support -e / -x to export the variable after editing
  if [ "$1" = "-e" ] || [ "$1" = "-x" ]; then
    prefix=export
    shift
  fi

  # collect all variable names for the current shell
  if [ -n "$ZSH_VERSION" ]; then
    names=(${(k)parameters})
  else
    names=($(compgen -v))
  fi

  tmpdir=$(mktemp -d) || return 1

  # snapshot each variable's value to a temp file so fzf's preview subprocess can read it
  for name in "${names[@]}"; do
    [[ $name =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    if [ -n "$ZSH_VERSION" ]; then
      printf '%s' "${(P)name}" > "$tmpdir/$name" 2>/dev/null
    else
      printf '%s' "${!name}" > "$tmpdir/$name" 2>/dev/null
    fi
  done

  # let the user pick a variable; preview shows its current value
  sel=$(printf '%s\n' "${names[@]}" \
    | grep -E '^[A-Za-z_][A-Za-z0-9_]*$' \
    | sort -u \
    | fzf --preview "cat -- '$tmpdir'/{}" --preview-window=right:60%:wrap)

  if [ -z "$sel" ]; then
    rm -rf "$tmpdir"
    return 0
  fi

  # read the current value before cleaning up temp files
  if [ -n "$ZSH_VERSION" ]; then
    current="${(P)sel}"
  else
    current="${!sel}"
  fi
  rm -rf "$tmpdir"

  if [ -n "$ZSH_VERSION" ]; then
    # push an editable assignment onto zle; enter applies, ctrl+c discards
    print -z "${prefix:+$prefix }${sel}=${(q)current}"
    return 0
  else
    # open readline with the current value pre-filled for inline editing
    IFS= read -r -e -i "$current" -p "$sel=" newval || return 0
    printf -v "$sel" '%s' "$newval"
    [ -n "$prefix" ] && export "$sel"
  fi
}

_fzf_run() {
  local sel

  # list all defined functions and let the user pick one
  if [ -n "$ZSH_VERSION" ]; then
    # zsh: (k)functions expands to function names
    sel=$(print -l ${(k)functions} \
      | grep -E '^[A-Za-z_][A-Za-z0-9_]*$' \
      | sort -u \
      | fzf --preview 'which {}' --preview-window=right:60%:wrap)
  else
    # bash: compgen -A function lists all defined function names
    sel=$(compgen -A function \
      | grep -E '^[A-Za-z_][A-Za-z0-9_]*$' \
      | sort -u \
      | fzf --preview 'declare -f {}' --preview-window=right:60%:wrap)
  fi

  [ -z "$sel" ] && return 0

  # push the selected function name onto the command line; user can add args before running
  print -z "$sel"
}

# ---------------------------------------------------------------- CREDENTIALS

_load_github_env() {
    local item token
    item=$(op item get "github" --fields "GITHUB_PERSONAL_ACCESS_TOKEN" --format json) || return 1
    token=$(printf '%s' "$item" | jq -r '.value') || return 1
    [[ -z "$token" ]] && { printf "Error: empty GITHUB_PERSONAL_ACCESS_TOKEN\n" >&2; return 1; }
    export GITHUB_PERSONAL_ACCESS_TOKEN="$token"
    printf "GITHUB_PERSONAL_ACCESS_TOKEN loaded\n"
}

_load_npm_env() {
    local item token
    item=$(op item get "npm" --fields "NPM_ACCESS_TOKEN" --format json) || return 1
    token=$(printf '%s' "$item" | jq -r '.value') || return 1
    [[ -z "$token" ]] && { printf "Error: empty NPM_ACCESS_TOKEN\n" >&2; return 1; }
    export NPM_ACCESS_TOKEN="$token"
    printf "NPM_ACCESS_TOKEN loaded\n"
}

_load_aws_env() {
    local item key secret
    item=$(op item get "aws-berat-user@beratiyilik" --fields "AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY" --format json) || return 1
    key=$(printf '%s' "$item" | jq -r '.[] | select(.label == "AWS_ACCESS_KEY_ID") | .value') || return 1
    secret=$(printf '%s' "$item" | jq -r '.[] | select(.label == "AWS_SECRET_ACCESS_KEY") | .value') || return 1
    [[ -z "$key" ]]    && { printf "Error: empty AWS_ACCESS_KEY_ID\n" >&2;     return 1; }
    [[ -z "$secret" ]] && { printf "Error: empty AWS_SECRET_ACCESS_KEY\n" >&2; return 1; }
    export AWS_ACCESS_KEY_ID="$key"
    export AWS_SECRET_ACCESS_KEY="$secret"
    printf "AWS credentials loaded\n"
}

# ------------------------------------------------------------------- TERMINAL

# displays a readline keyboard shortcuts reference
_rl() {
  cat <<'EOF'
readline (emacs mode) - keyboard shortcuts

  Move:
    ^a  start of line          ^e  end of line
    ^b  back one char          ^f  forward one char
    M-b back one word          M-f forward one word
    ^p  previous history       ^n  next history

  Delete / change:
    ^u  delete to line start   ^k  delete to line end
    ^w  delete word backward   M-d delete word forward
    ^h  delete char backward   ^d  delete char forward (EOF if line empty)

  Misc:
    ^r  reverse history search ^l  clear screen
    ^y  yank (paste)           ^_  undo
    ^c  interrupt              ^x^e edit current line in $EDITOR

  Note: M- (Meta) = Option/Alt, or press ESC then the key.
EOF
}

# opens a new terminal window with the specified command and profile
_trm_new_window() {
    _trm_new_window_usage() {
        printf "%b%s%b %bnewterm%b %b[-c|--command \"command\"] [-p|--profile \"profile\"] [-h|--help]%b\n" \
            "$STYLE_BOLD" "Usage:" "$STYLE_RESET" \
            "$STYLE_BOLD" "$STYLE_RESET" \
            "$FG_YELLOW" "$STYLE_RESET" >&2
    }

    local profile="Basic"
    local cmd=""

    if ! is_macos; then
        printf "%bThis script only works on macOS%b\n" "$FG_RED" "$STYLE_RESET" >&2
        return 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c | --command)
                if [[ -z "$2" || "$2" == -* ]]; then
                    printf "%bError:%b Command option requires a value\n" "$COLOR_ERROR" "$STYLE_RESET" >&2
                    _trm_new_window_usage
                    return 1
                fi
                cmd="$2"
                shift 2
                ;;
            -p | --profile)
                if [[ -z "$2" || "$2" == -* ]]; then
                    printf "%bError:%b Profile option requires a value\n" "$COLOR_ERROR" "$STYLE_RESET" >&2
                    _trm_new_window_usage
                    return 1
                fi
                profile="$2"
                shift 2
                ;;
            -h | --help)
                _trm_new_window_usage
                return 0
                ;;
            *)
                printf "%bInvalid option:%b %b%s%b\n" "$COLOR_ERROR" "$STYLE_RESET" "$FG_YELLOW" "$1" "$STYLE_RESET" >&2
                _trm_new_window_usage
                return 1
                ;;
        esac
    done

    # shell-quote cmd to prevent AppleScript injection
    # escape backslashes and double quotes for AppleScript string literal syntax
    local applescript_cmd=""
    if [[ -n "$cmd" ]]; then
        local escaped_cmd="${cmd//\\/\\\\}"
        escaped_cmd="${escaped_cmd//\"/\\\"}"
        applescript_cmd="do script \"${escaped_cmd}\" in newWindow"
    fi

    # escape backslashes and double quotes in profile for AppleScript string literal syntax
    local escaped_profile="${profile//\\/\\\\}"
    escaped_profile="${escaped_profile//\"/\\\"}"

    osascript <<EOF
tell application "Terminal"
  activate
  try
    set newWindow to do script ""
    try
      set current settings of newWindow to settings set "$escaped_profile"
    on error
      display dialog "Warning: Profile '$escaped_profile' not found." buttons {"OK"} default button "OK" with icon caution
    end try
${applescript_cmd}
  on error errMsg
    display dialog "Error: " & errMsg buttons {"OK"} default button "OK" with icon stop
    return false
  end try
end tell
EOF

    if [[ $? -ne 0 ]]; then
        printf "%bFailed to run Terminal command%b\n" "$FG_RED" "$STYLE_RESET" >&2
        return 1
    fi
}

# opens a new terminal window in the current directory
_trm_reopen_here() {
    local dir="$(pwd)"
    _trm_new_window -c "cd \"${dir}\" && clear"
}

# resizes the current terminal window to a specified size (xs, small, medium, large, xl)
_trm_resize() {
  # this script relies on osascript, only available on macOS
  if ! is_macos; then
    printf "%bThis script only works on macOS%b\n" "$FG_RED" "$STYLE_RESET" >&2
    return 1
  fi

  local size="$1"

  # map named size to window pixel dimensions and terminal column/row counts
  case "$size" in
  xs)     W=400;  H=300;  COLS=60;  ROWS=15 ;;
  small)  W=600;  H=400;  COLS=80;  ROWS=20 ;;
  medium) W=900;  H=600;  COLS=120; ROWS=30 ;;
  large)  W=1300; H=850;  COLS=160; ROWS=45 ;;
  xl)     W=1800; H=1000; COLS=200; ROWS=55 ;;
  *)
    # unknown size argument: print error and usage, then bail
    printf "%bError:%b Invalid size %b%s%b\n" "$COLOR_ERROR" "$STYLE_RESET" "$FG_YELLOW" "$size" "$STYLE_RESET" >&2
    printf "%b%s%b %bresize%b %b<xs|small|medium|large|xl>%b\n" \
      "$STYLE_BOLD" "Usage:" "$STYLE_RESET" \
      "$STYLE_BOLD" "$STYLE_RESET" \
      "$FG_YELLOW" "$STYLE_RESET" >&2
    return 1
    ;;
  esac

  # recompute window bounds keeping the window centered on its current center point
  osascript -e "tell application \"Terminal\"
    set b to bounds of front window
    set x to item 1 of b
    set y to item 2 of b
    set r to item 3 of b
    set bt to item 4 of b
    set cx to (x + r) / 2
    set cy to (y + bt) / 2
    set newX to cx - ($W / 2)
    set newY to cy - ($H / 2)
    set bounds of front window to {newX, newY, newX + $W, newY + $H}
  end tell"

  # resize the underlying tty so programs relying on COLUMNS/LINES adjust too
  printf '\e[8;%d;%dt' "$ROWS" "$COLS"
}

_fzf_search() {
  local f
  f=$(find . -type f -not -path "./.git/*" -not -path "./node_modules/*" | fzf --prompt="Open file: " --preview "bat --color=always --style=numbers --line-range=:500 {}" --preview-window="right:50%:nohidden:wrap")
  [[ -n "$f" ]] && ${EDITOR:-nano} "$f"
}

_fzf_history() {
  local selected
  if [ -n "$ZSH_VERSION" ]; then
    selected=$(command grep -E '^: [0-9]+:[0-9]+;' ~/.zsh_history \
      | LC_ALL=C sed 's/^: [0-9]*:[0-9]*;//' \
      | awk '!seen[$0]++' \
      | awk '{lines[NR]=$0} END {for(i=NR;i>=1;i--) print lines[i]}' \
      | fzf --no-sort --exact --scheme=history --tiebreak=length,index --prompt="History: " --preview='')
    print -z "$selected"
  else
    selected=$(command grep -v '^#' ~/.bash_history \
      | awk '!seen[$0]++' \
      | awk '{lines[NR]=$0} END {for(i=NR;i>=1;i--) print lines[i]}' \
      | fzf --no-sort --exact --scheme=history --tiebreak=length,index --prompt="History: " --preview='')
    READLINE_LINE="$selected"
    READLINE_POINT=${#READLINE_LINE}
  fi
}

_fzf_kill() {
  local procs jobs_list combined

  jobs_list=$(jobs -l 2>/dev/null | awk '{
    pid=""
    for(i=1;i<=NF;i++) if($i~/^[0-9]+$/ && $i+0>1) {pid=$i; break}
    if(pid!="") printf "\033[32mJOB\033[0m    %-6s  %s\n", pid, $0
  }')

  procs=$(ps aux | awk 'NR>1 {
    cmd=substr($0, index($0,$11))
    if(length(cmd)>60) cmd=substr(cmd,1,60)"..."
    printf "\033[31mPROC\033[0m   %-6s  %-10s  %s\n", $2, $1, cmd
  }')

  if [[ -n "$jobs_list" ]]; then
    combined=$(printf "TYPE   PID     INFO\n%s\n%s" "$jobs_list" "$procs")
  else
    combined=$(printf "TYPE   PID     USER        COMMAND\n%s" "$procs")
  fi

  local selected
  selected=$(printf '%s\n' "$combined" | fzf -m --prompt="Kill: " --header-lines=1 --ansi --preview='' | awk '{print $2}' | command grep -E '^[0-9]+$' | tr '\n' ' ')

  [[ -n "$selected" ]] && print -z "kill -9 ${selected}"
}

# --------------------------------------------------------------------- EDITOR

# unified alias to open different code editors
_code() {
    _code_usage() {
        printf "%b%s%b %bcode%b %b[-v|--vsc] [-a|--ads] [-c|--cursor] [-vt|--vsc-tunnel] [-ct|--cursor-tunnel] [-h|--help]%b %b[file|folder|...]%b\n" \
            "$STYLE_BOLD" "Usage:" "$STYLE_RESET" \
            "$STYLE_BOLD" "$STYLE_RESET" \
            "$FG_YELLOW" "$STYLE_RESET" \
            "$FG_YELLOW" "$STYLE_RESET" >&2
    }

    local VSCODE_BASE_PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
    local ADS_BASE_PATH="/Applications/Azure Data Studio.app/Contents/Resources/app/bin"
    local CURSOR_BASE_PATH="/Applications/Cursor.app/Contents/Resources/app/bin"

    local VSCODE_PATH="${VSCODE_BASE_PATH}/code"
    local ADS_PATH="${ADS_BASE_PATH}/code"
    local CURSOR_PATH="${CURSOR_BASE_PATH}/cursor"
    local VSCODE_TUNNEL_PATH="${VSCODE_BASE_PATH}/code_tunnel"
    local CURSOR_TUNNEL_PATH="${CURSOR_BASE_PATH}/cursor_tunnel"

    local editor="vsc"
    local args=()

    if [[ $# -eq 0 ]]; then
        "$VSCODE_PATH"
        return
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v | --vsc)            editor="vsc";          shift ;;
            -a | --ads)            editor="ads";          shift ;;
            -c | --cursor)         editor="cursor";       shift ;;
            -vt | --vsc-tunnel)    editor="vsc-tunnel";   shift ;;
            -ct | --cursor-tunnel) editor="cursor-tunnel"; shift ;;
            -h | --help)           _code_usage; return ;;
            *)                     args+=("$1"); shift ;;
        esac
    done

    case "$editor" in
        vsc)           "$VSCODE_PATH"        "${args[@]}" ;;
        ads)           "$ADS_PATH"           "${args[@]}" ;;
        cursor)        "$CURSOR_PATH"        "${args[@]}" ;;
        vsc-tunnel)    "$VSCODE_TUNNEL_PATH" "${args[@]}" ;;
        cursor-tunnel) "$CURSOR_TUNNEL_PATH" "${args[@]}" ;;
    esac
}

# ------------------------------------------------------------------- SECURITY

# generates a secure random password
_genpass() {
    _genpass_usage() {
        printf "usage: _genpass [length]\n       length must be a positive integer >= 8 (default: 16)\n" >&2
    }

    local length=${1:-16}

    if ! [[ "$length" =~ ^[0-9]+$ ]]; then
        printf "Error: Password length must be a positive integer\n" >&2
        _genpass_usage
        return 1
    fi

    if [[ "$length" -lt 8 ]]; then
        printf "Error: Password length must be at least 8 characters\n" >&2
        _genpass_usage
        return 1
    fi

    local allowed_chars='A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~'
    LC_ALL=C tr -dc "$allowed_chars" </dev/urandom | head -c "$length"
    printf "\n"
}

# -------------------------------------------------------------------- DISPLAY

# global pid tracker for the spinner background process
: "${_SPINNER_PID:=}"

# Spinner definitions - only defined here if functions.sh was not sourced first.
# When sourced standalone (e.g. by _ai_rebase shim), these provide the implementation.
if ! command -v _spinner_start >/dev/null 2>&1; then
  _spinner_start() {
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
    _SPINNER_PID=$!
    disown "$_SPINNER_PID" 2>/dev/null || true
  }

  _spinner_stop() {
    [[ -n "${_SPINNER_PID:-}" ]] || return 0
    kill "$_SPINNER_PID" 2>/dev/null || true
    _SPINNER_PID=""
    printf "\r                    \r"
  }
fi

## eof
