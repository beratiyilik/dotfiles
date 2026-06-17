# $DOTFILES_DIR/lib/log.sh

# set -e
# set -euo pipefail

# set -x

# guard against multiple inclusion
[ -n "$LOG_SH_INCLUDED" ] && return 0

# check shell compatibility
if [ -z "$BASH_VERSION" ] && [ -z "$ZSH_VERSION" ]; then
  echo "Error: log.sh requires Zsh or Bash" >&2
  return 1
fi

# initialize guard
LOG_SH_INCLUDED=1

# default configuration
LOG_APP=${LOG_APP:-app}
LOG_LEVEL=${LOG_LEVEL:-INFO}
LOG_FORMAT=${LOG_FORMAT:-text}
LOG_TIME_UTC=${LOG_TIME_UTC:-1}
NOCOLOR=${NOCOLOR:-0}

# generate TRACE_ID if not already set
if [ -z "${TRACE_ID:-}" ]; then
  if command -v uuidgen >/dev/null 2>&1; then
    TRACE_ID=$(uuidgen | cut -c1-6)
  elif command -v openssl >/dev/null 2>&1; then
    TRACE_ID=$(openssl rand -hex 3)
  else
    TRACE_ID="$$"
  fi
  export TRACE_ID
fi

# define severity level rankings (POSIX compliant)
_LOG_LEVEL_TRACE=10
_LOG_LEVEL_DEBUG=20
_LOG_LEVEL_INFO=30
_LOG_LEVEL_SUCCESS=35
_LOG_LEVEL_WARN=40
_LOG_LEVEL_ERROR=50
_LOG_LEVEL_FATAL=60

# set +x

# get numeric level value
_get_level_value() {
  case "$1" in
    TRACE) echo "$_LOG_LEVEL_TRACE" ;;
    DEBUG) echo "$_LOG_LEVEL_DEBUG" ;;
    INFO) echo "$_LOG_LEVEL_INFO" ;;
    SUCCESS) echo "$_LOG_LEVEL_SUCCESS" ;;
    WARN) echo "$_LOG_LEVEL_WARN" ;;
    ERROR) echo "$_LOG_LEVEL_ERROR" ;;
    FATAL) echo "$_LOG_LEVEL_FATAL" ;;
    *) echo "$_LOG_LEVEL_INFO" ;;  # Default to INFO
  esac
}

# determine if output is a TTY for color decision
_is_tty() {
  [ -t 1 ] && [ "${NOCOLOR:-0}" != "1" ]
}

# setup ANSI colors if terminal supports them
if _is_tty; then
  C_TRACE="\033[2m"        # dim
  C_DEBUG="\033[35m"       # magenta
  C_INFO="\033[34m"        # blue
  C_SUCCESS="\033[32m"     # green
  C_WARN="\033[33m"        # yellow
  C_ERROR="\033[31m"       # red
  C_FATAL="\033[31;1m"     # bright red
  C_RESET="\033[0m"
else
  C_TRACE=""
  C_DEBUG=""
  C_INFO=""
  C_SUCCESS=""
  C_WARN=""
  C_ERROR=""
  C_FATAL=""
  C_RESET=""
fi

# generate ISO-8601 timestamp
_ts() {
  local ts
  
  if [ "${1:-1}" = "1" ]; then  # UTC
    if command -v gdate >/dev/null 2>&1; then
      ts=$(gdate -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
    else
      ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    fi
  else  # Local time
    if command -v gdate >/dev/null 2>&1; then
      ts=$(gdate '+%Y-%m-%dT%H:%M:%S.%3N%z')
    else
      ts=$(date '+%Y-%m-%dT%H:%M:%S%z')
    fi
  fi
  
  printf "%s" "$ts"
}

# get epoch milliseconds for timing functions
_epoch_ms() {
  if command -v gdate >/dev/null 2>&1; then
    gdate +%s%3N
  else
    echo $(( $(date +%s) * 1000 ))
  fi
}

# json escape function for special characters
_json_escape() {
  local str="$1"
  # POSIX compliant string escaping
  str=$(printf "%s" "$str" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/	/\\t/g' | sed 's/\n/\\n/g' | sed 's/\r/\\r/g')
  printf "%s" "$str"
}

# check if a log level should be emitted based on configured LOG_LEVEL
_should_log() {
  local level_val=$(_get_level_value "$(printf "%s" "$1" | tr 'a-z' 'A-Z')")
  local threshold_val=$(_get_level_value "$(printf "%s" "$2" | tr 'a-z' 'A-Z')")
  
  [ "$level_val" -ge "$threshold_val" ]
}

# format log message in text format
_log_format_text() {
  local level="$1"
  local msg="$2"
  local app="$3"
  local trace_id="$4"
  local use_utc="$5"
  shift 5
  
  local color_var="C_${level}"
  local color=""
  eval "color=\$$color_var"
  
  local timestamp=$(_ts "$use_utc")
  local tag="${color}[${level}]${C_RESET}"
  
  printf "%s %s app=%s pid=%s trace=%s msg=%s" \
    "$timestamp" "$tag" "$app" "$$" "$trace_id" "$(printf "%s" "$msg" | sed 's/ /\\ /g')"
  
  # add extra fields if present
  while [ $# -gt 0 ]; do
    local field="$1"
    # only add fields that match key=value format
    if printf "%s" "$field" | grep -q "^[[:alnum:]_]\+=.*$"; then
      printf " %s" "$field"
    fi
    shift
  done
  
  printf "\n"
}

# format log message in JSON format
_log_json() {
  local level="$1"
  local msg="$2"
  local app="$3"
  local trace_id="$4"
  local use_utc="$5"
  shift 5
  
  local timestamp=$(_ts "$use_utc")
  local escaped_msg=$(_json_escape "$msg")
  
  printf "{\"ts\":\"%s\",\"level\":\"%s\",\"app\":\"%s\",\"pid\":%s,\"trace\":\"%s\",\"msg\":\"%s\"" \
    "$timestamp" "$level" "$app" "$$" "$trace_id" "$escaped_msg"
  
  # add extra fields if present
  while [ $# -gt 0 ]; do
    local field="$1"
    # extract key and value if it matches the pattern
    if printf "%s" "$field" | grep -q "^[[:alnum:]_]\+=.*$"; then
      key=$(printf "%s" "$field" | cut -d= -f1)
      val=$(printf "%s" "$field" | cut -d= -f2-)
      escaped_val=$(_json_escape "$val")
      printf ",\"%s\":\"%s\"" "$key" "$escaped_val"
    fi
    shift
  done
  
  printf "}\n"
}


# main log function
# log() { }

# trace() { }
# debug() { }
# info() { }
# success() { }
# warn() { }
# error() { }
# fatal() { }
