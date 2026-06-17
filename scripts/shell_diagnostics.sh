#!/bin/sh
#!/usr/bin/env sh
# $DOTFILES_DIR/scripts/shell_diagnostics.sh
#
# Description:
#   A comprehensive shell diagnostic tool that reports detailed information about 
#   your shell environment including shell type, user environment, system details, 
#   terminal capabilities, and environment variables.
#
# Usage:
#   shell_diagnostics.sh [OPTIONS]
#
# Options:
#   -h, --help           Show help message
#   -v, --verbose        Enable verbose output
#   -s, --silent         Suppress all output
#   -n, --no-color       Disable colored output
#   -o, --format FORMAT  Output format: text (default), json, minimal
#   -f, --force          Force execution even when unsafe
#   -d, --dry-run        Show what would be done without doing it
#   --version            Show version information
#
# Examples:
#   shell_diagnostics.sh                 # Run with default settings
#   shell_diagnostics.sh --verbose       # Show additional information
#   shell_diagnostics.sh --format json   # Output in JSON format
#   shell_diagnostics.sh --no-color      # Disable colored output
#
# Dependencies:
#   - POSIX-compliant shell (sh, bash, zsh)
#   - Standard Unix utilities: ps, tput, grep, wc, tr
#
# Environment Variables:
#   - LINE_WIDTH: Sets the width of output lines (defaults to terminal width)
#
# Return Codes:
#   0  - Success (EXIT_SUCCESS)
#   64 - Invalid usage (EXIT_INVALID_USAGE)
#   127 - Command not found (EXIT_CMD_NOT_FOUND)
#   20 - Authentication failed (EXIT_AUTH_FAILED)
#
# CAUTION:
#   - Uses 'set -o errexit' to exit immediately on errors
#   - Uses 'set -o nounset' to treat unset variables as errors
#   - Uses 'set -o pipefail' if available to catch pipeline failures

# exit immediately if a command exits with non-zero status (-e)
set -o errexit
# treat unset variables as an error (-u)
set -o nounset
# exit if any command in a pipeline fails (-o pipefail)
if [ -n "${BASH_VERSION:-}" ] || [ -n "${ZSH_VERSION:-}" ]; then
  set -o pipefail 2>/dev/null || true
fi
# restrict field separators to newline and tab for safety
IFS=$'\n\t'

# define exit codes as constants for better readability
EXIT_SUCCESS=0
EXIT_INVALID_USAGE=64
EXIT_CMD_NOT_FOUND=127
EXIT_AUTH_FAILED=20

# default configuration
DRY_RUN=false  # execute commands (not in dry run mode)
FORCE=false    # do not force execution unless necessary
SILENT=false   # do not suppress output
VERBOSE=true   # enable verbose output
USE_COLOR=true # use color in output
OUTPUT_FORMAT="text"  # Options: text, json, minimal

LINE_WIDTH=${LINE_WIDTH:-$(tput cols 2>/dev/null || echo 40)}

init_styling() {
  # reset styling if colors are disabled
  if ! "$USE_COLOR"; then
    # style reset and attributes
    STYLE_BLINK_OFF=""
    STYLE_BLINK_ON=""
    STYLE_BOLD=""
    STYLE_RESET=""
    # base colors
    FG_BLUE=""
    FG_CYAN=""
    FG_GRAY=""
    FG_GREEN=""
    FG_MAGENTA=""
    FG_RED=""
    FG_WHITE=""
    FG_YELLOW=""
    return 0
  fi
  
  # only set colors if connected to a terminal
  if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    # style reset and attributes
    STYLE_BLINK_OFF="$(tput sgr0)"  # Fixed: Was same as BLINK_ON
    STYLE_BLINK_ON="$(tput blink)"
    STYLE_BOLD="$(tput bold)"
    STYLE_RESET="$(tput sgr0)"    
    # base colors
    FG_BLUE="$(tput setaf 4)"
    FG_CYAN="$(tput setaf 6)"
    FG_GRAY="$(tput setaf 8)"
    FG_GREEN="$(tput setaf 2)"
    FG_MAGENTA="$(tput setaf 5)"
    FG_RED="$(tput setaf 1)"
    FG_WHITE="$(tput setaf 7)"    
    FG_YELLOW="$(tput setaf 3)"
  else
    # fallback to ANSI escape sequences
    # style reset and attributes
    STYLE_BLINK_OFF=$'\033[25m'  # Fixed: Correct ANSI code for blink off
    STYLE_BLINK_ON=$'\033[5m'
    STYLE_BOLD=$'\033[1m'
    STYLE_RESET=$'\033[0m'
    # base colors
    FG_BLUE=$'\033[38;5;31m'
    FG_CYAN=$'\033[38;5;66m'
    FG_GRAY=$'\033[38;5;244m'
    FG_GREEN=$'\033[38;5;76m'
    FG_MAGENTA=$'\033[0;35m'
    FG_RED=$'\033[38;5;196m'
    FG_WHITE=$'\033[0;37m'
    FG_YELLOW=$'\033[38;5;220m'
  fi
}

log() {
  level="${1:-INFO}"
  message="${2:-""}"
  upper_level=$(echo "$level" | tr '[:lower:]' '[:upper:]')

  # do not log if silent mode is enabled or if verbose mode is disabled and the log level is not ERROR
  if [[ "$SILENT" == true || ( "$VERBOSE" == false && "$upper_level" != ERROR ) ]]; then return; fi

  prefix=""
  case "$upper_level" in
    "DEBUG")
      prefix="${STYLE_BOLD}${FG_CYAN}[DEBUG]${STYLE_RESET} "
      ;;
    "INFO")
      prefix="${STYLE_BOLD}${FG_BLUE}[INFO]${STYLE_RESET} "
      ;;
    "SUCCESS")
      prefix="${STYLE_BOLD}${FG_GREEN}[SUCCESS]${STYLE_RESET} "
      ;;
    "WARN")
      prefix="${STYLE_BOLD}${FG_YELLOW}[WARN]${STYLE_RESET} "
      ;;
    "ERROR")
      prefix="${STYLE_BOLD}${FG_RED}[ERROR]${STYLE_RESET} "
      ;;
    *)
      prefix="${STYLE_BOLD}${FG_MAGENTA}[LOG]${STYLE_RESET} "
      ;;
  esac

  if [[ "$upper_level" == "ERROR" || "$upper_level" == "WARN" ]]; then
    printf "%s %s\n" "$prefix" "$message" >&2
  else
    printf "%s %s\n" "$prefix" "$message"
  fi
}

debug()   { log "DEBUG" "$1"; }
info()    { log "INFO" "$1"; }
success() { log "SUCCESS" "$1"; }
warn()    { log "WARN" "$1"; }
error()   { log "ERROR" "$1"; }
print()   { [ "$SILENT" = false ] && printf "$@"; }

print_line() {
  local char="${1:-=}"
  local length="${2:-$LINE_WIDTH}"
  printf '%*s\n' "$length" '' | tr ' ' "$char"
}

print_section_header() {
  local title="$1"

  [ "$SILENT" = true ] && return 0

  if [ "$OUTPUT_FORMAT" = "minimal" ]; then
    printf "\n%s:\n" "$title"
    return 0
  fi

  printf "\n%s%s%s\n" "${STYLE_BOLD}${FG_GREEN}" "$title" "${STYLE_RESET}"
  printf "%s\n" "${FG_BLUE}$(print_line '-' )${STYLE_RESET}"
}

print_item() {
  local label="$1"
  local value="$2"

  [ "$SILENT" = true ] && return 0

  if [ "$OUTPUT_FORMAT" = "minimal" ]; then
    printf "%s: %s\n" "$label" "$value"
    return 0
  fi

  printf "%-22s %s\n" "* $label:" "${STYLE_BOLD}$value${STYLE_RESET}"
}

print_report_header() {
  [ "$SILENT" = true ] && return 0

  if [ "$OUTPUT_FORMAT" = "minimal" ]; then
    printf "Shell Diagnostic Report - %s\n\n" "$(date "+%Y-%m-%d %H:%M:%S")"
    return 0
  fi

  printf '%s\n' "${STYLE_BOLD}${FG_BLUE}$(print_line '=' )${STYLE_RESET}"
  printf '%s\n' "${STYLE_BOLD}Shell Diagnostic Report${STYLE_RESET}"
  printf '%s\n' "${FG_BLUE}$(print_line '-' )${STYLE_RESET}"
  printf '%s\n' "${STYLE_BOLD}Generated:${STYLE_RESET} $(date "+%Y-%m-%d %H:%M:%S")"
  printf '%s\n' "${FG_BLUE}$(print_line '=' )${STYLE_RESET}"
}

print_report_footer() {
  [ "$SILENT" = true ] && return 0

  if [ "$OUTPUT_FORMAT" = "minimal" ]; then
    printf "\nEnd of Shell Diagnostic Report\n"
    return 0
  fi

  printf '\n%s\n' "${FG_BLUE}$(print_line '=' )${STYLE_RESET}"
  printf '%s\n' "${STYLE_BOLD}End of Shell Diagnostic Report${STYLE_RESET}"
  printf '%s\n' "${FG_BLUE}$(print_line '=' )${STYLE_RESET}"
}

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Shell Diagnostic Tool: Reports detailed information about your shell environment

Options:
  -h, --help           Show this help message
  -v, --verbose        Enable verbose output
  -s, --silent         Suppress all output
  -n, --no-color       Disable colored output
  -o, --format FORMAT  Output format: text (default), json, minimal
  -f, --force          Force execution even when unsafe
  -d, --dry-run        Show what would be done without doing it
  --version            Show version information

Examples:
  $(basename "$0")                 # Run with default settings
  $(basename "$0") --verbose       # Show additional information
  $(basename "$0") --format json   # Output in JSON format
  $(basename "$0") --no-color      # Disable colored output

EOF
}

show_version() {
  log "Shell Diagnostics Tool v1.0.0"
  log "Copyright (C) $(date +%Y)"
  log "License: GPL-3.0-or-later"
}

parse_args() {
  # reset options
  DRY_RUN=false
  FORCE=false
  SILENT=false
  VERBOSE=true
  USE_COLOR=true
  OUTPUT_FORMAT="text"

  while (($# > 0)); do
    case "$1" in
    -d | --dry-run)
      DRY_RUN=true
      ;;
    -f | --force)
      FORCE=true
      ;;
    -s | --silent)
      SILENT=true
      VERBOSE=false
      ;;
    -v | --verbose)
      VERBOSE=true
      SILENT=false
      ;;
    --no-color | -n)
      USE_COLOR=false
      ;;
    -o | --format)
      if [ -z "${2:-}" ]; then
        error "Missing format value"
        show_help
        exit $EXIT_INVALID_USAGE
      fi
      case "$2" in
        text|json|minimal)
          OUTPUT_FORMAT="$2"
          ;;
        *)
          error "Invalid format: $2. Must be one of: text, json, minimal"
          show_help
          exit $EXIT_INVALID_USAGE
          ;;
      esac
      shift
      ;;
    --help | -h)
      show_help
      exit $EXIT_SUCCESS
      ;;
    --version)
      show_version
      exit $EXIT_SUCCESS
      ;;
    -*)
      error "Unknown option: $1"
      show_help
      exit $EXIT_INVALID_USAGE
      ;;
    *)
      error "Too many positional arguments"
      show_help
      exit $EXIT_INVALID_USAGE
      ;;
    esac
    shift
  done

  return $EXIT_SUCCESS
}

get_shell_information() {
  print_section_header "SHELL INFORMATION"
  
  # shell binary
  shell_bin=$(ps -p "$$" -o comm= 2>/dev/null || echo "unknown")
  print_item "Shell binary" "$shell_bin"
  
  # shell name
  print_item "Shell name" "$0"
  
  # shell PID
  print_item "Shell PID" "$$"
  
  # parent process
  parent_pid=$(ps -o ppid= -p "$$" 2>/dev/null | tr -d ' ' || echo "")
  if [ -n "$parent_pid" ]; then
    parent_name=$(ps -p "$parent_pid" -o comm= 2>/dev/null || echo "unknown")
    print_item "Parent process" "$parent_name ($parent_pid)"
  fi
  
  # shell type and version
  get_shell_type_and_mode
  
  # shell startup files
  get_shell_startup_files
}

get_shell_type_and_mode() {
  # detect shell type and version
  if [ -n "${BASH_VERSION:-}" ]; then
    print_item "Shell type" "bash ${BASH_VERSION}"
    
    # detect shell mode
    shell_mode=""
    [ -n "${BASH_SUBSHELL:-}" ] && [ "${BASH_SUBSHELL:-0}" -gt 0 ] && shell_mode="subshell, "
    
    case "$-" in
      *i*) shell_mode="${shell_mode}interactive, " ;;
      *)   shell_mode="${shell_mode}non-interactive, " ;;
    esac
    
    # check if login shell
    if shopt -q login_shell 2>/dev/null; then
      shell_mode="${shell_mode}login"
    else
      shell_mode="${shell_mode}non-login"
    fi
    
    print_item "Shell mode" "$shell_mode"
    
    # count enabled shell options
    enabled_count=$(shopt 2>/dev/null | grep -E '^[a-z].*on$' | wc -l | tr -d ' ' || echo "unknown")
    print_item "Bash options" "$enabled_count enabled"
    
  elif [ -n "${ZSH_VERSION:-}" ]; then
    print_item "Shell type" "zsh ${ZSH_VERSION}"
    
    # detect shell mode for zsh
    shell_mode=""
    
    # check for subshell in zsh
    if [ "${ZSH_SUBSHELL:-0}" -gt 0 ]; then
      shell_mode="subshell, "
    fi
    
    case "$-" in
      *i*) shell_mode="${shell_mode}interactive, " ;;
      *)   shell_mode="${shell_mode}non-interactive, " ;;
    esac
    
    # check if login shell in zsh
    if [ -o login ] 2>/dev/null; then
      shell_mode="${shell_mode}login"
    else
      shell_mode="${shell_mode}non-login"
    fi
    
    print_item "Shell mode" "$shell_mode"
    
    # zsh options count (if applicable)
    if command -v setopt >/dev/null 2>&1; then
      zsh_options_count=$(setopt 2>/dev/null | wc -l | tr -d ' ' || echo "unknown")
      print_item "Zsh options" "$zsh_options_count enabled"
    fi
    
  elif [ -n "${KSH_VERSION:-}" ]; then
    print_item "Shell type" "ksh ${KSH_VERSION}"
    
    # detect shell mode
    shell_mode=""
    case "$-" in
      *i*) shell_mode="interactive" ;;
      *)   shell_mode="non-interactive" ;;
    esac
    print_item "Shell mode" "$shell_mode"
    
  else
    print_item "Shell type" "unknown or pure sh"
    
    # detect shell mode for generic shell
    shell_mode=""
    case "$-" in
      *i*) shell_mode="interactive" ;;
      *)   shell_mode="non-interactive" ;;
    esac
    print_item "Shell mode" "$shell_mode"
  fi
}

get_shell_startup_files() {
  debug "Checking for shell startup files"
  if [ -n "${BASH_VERSION:-}" ]; then
    for file in $HOME/.bashrc $HOME/.bash_profile $HOME/.profile $HOME/.bash_login; do
      [ -f "$file" ] && print_item "Found startup" "$file"
    done
  elif [ -n "${ZSH_VERSION:-}" ]; then
    for file in $HOME/.zshrc $HOME/.zprofile $HOME/.zshenv $HOME/.zlogin; do
      [ -f "$file" ] && print_item "Found startup" "$file"
    done
  fi
  debug "Shell startup files checked"
}

get_user_environment() {
  print_section_header "USER ENVIRONMENT"
  
  # user info
  user=$(whoami 2>/dev/null || echo "unknown")
  print_item "User" "$user"
  
  # UID/GID
  uid=$(id -u 2>/dev/null || echo "unknown")
  gid=$(id -g 2>/dev/null || echo "unknown")
  print_item "UID/GID" "$uid/$gid"
  
  # groups
  groups=$(groups 2>/dev/null | tr ' ' ',' || echo "unknown")
  print_item "Groups" "$groups"
  
  # working directory
  print_item "Working dir" "$(pwd 2>/dev/null || echo "unknown")"
  
  # home directory
  print_item "Home directory" "${HOME:-unknown}"
}

get_system_information() {
  print_section_header "SYSTEM INFORMATION"
  
  # OS info
  if command -v uname >/dev/null 2>&1; then
    os_name=$(uname -s 2>/dev/null || echo "unknown")
    os_ver=$(uname -r 2>/dev/null || echo "unknown")
    print_item "OS" "$os_name $os_ver"
  fi
  
  # distribution info
  get_distribution_info
}

get_distribution_info() {
  if [ -f /etc/os-release ]; then
    distro=$(grep -E "^PRETTY_NAME=" /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "unknown")
    [ -n "$distro" ] && print_item "Distribution" "$distro"
  elif [ -f /etc/lsb-release ]; then
    distro=$(grep -E "^DISTRIB_DESCRIPTION=" /etc/lsb-release 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "unknown")
    [ -n "$distro" ] && print_item "Distribution" "$distro"
  fi
}

get_terminal_information() {
  print_section_header "TERMINAL INFORMATION"
  
  # TTY
  tty_val=$(tty 2>/dev/null || echo "unknown")
  print_item "Terminal" "$tty_val"
  
  # terminal type
  [ -n "${TERM:-}" ] && print_item "Terminal type" "$TERM"
  
  # terminal size and colors
  if command -v tput >/dev/null 2>&1; then
    cols=$(tput cols 2>/dev/null || echo "unknown")
    lines=$(tput lines 2>/dev/null || echo "unknown")
    
    if [ "$cols" != "unknown" ] && [ "$lines" != "unknown" ]; then
      print_item "Terminal size" "${cols}x${lines} characters"
    fi
    
    colors=$(tput colors 2>/dev/null || echo "unknown")
    [ "$colors" != "unknown" ] && print_item "Color support" "$colors colors"
  fi
}

get_shell_capabilities() {
  print_section_header "SHELL CAPABILITIES"
  
  if [ -n "${BASH_VERSION:-}" ] || [ -n "${ZSH_VERSION:-}" ]; then
    # aliases
    alias_count=$(alias 2>/dev/null | wc -l | tr -d ' ' || echo "unknown")
    print_item "Aliases defined" "$alias_count"
    
    # functions
    if [ -n "${BASH_VERSION:-}" ]; then
      func_count=$(declare -F 2>/dev/null | wc -l | tr -d ' ' || echo "unknown")
      print_item "Functions defined" "$func_count"
    elif [ -n "${ZSH_VERSION:-}" ]; then
      func_count=$(functions 2>/dev/null | wc -l | tr -d ' ' || echo "unknown")
      print_item "Functions defined" "$func_count"
    fi
  fi
}

get_path_and_environment() {
  print_section_header "PATH & ENVIRONMENT"
  debug "Checking PATH and environment variables"
  
  # shell paths
  for shell in bash zsh ksh sh; do
    if command -v "$shell" >/dev/null 2>&1; then
      shell_path=$(command -v "$shell" 2>/dev/null || echo "not found")
      print_item "Path to $shell" "$shell_path"
    fi
  done
  
  # environment variable count
  env_count=$(env 2>/dev/null | wc -l | tr -d ' ' || echo "unknown")
  print_item "Environment vars" "$env_count total"
  
  debug "Checking environment variables before PATH"
  
  # important environment variables
  get_important_env_vars
  
  # path entries
  get_path_entries
}

get_important_env_vars() {
  # more reliable way to get environment variables without eval
  for var_name in SHELL PATH LANG LC_ALL EDITOR VISUAL PAGER DISPLAY; do
    # use printf %s to avoid issues with special characters
    case "$var_name" in
      SHELL)  var_value="${SHELL:-}" ;;
      PATH)   var_value="${PATH:-}" ;;
      LANG)   var_value="${LANG:-}" ;;
      LC_ALL) var_value="${LC_ALL:-}" ;;
      EDITOR) var_value="${EDITOR:-}" ;;
      VISUAL) var_value="${VISUAL:-}" ;;
      PAGER)  var_value="${PAGER:-}" ;;
      DISPLAY) var_value="${DISPLAY:-}" ;;
      *) var_value="" ;;
    esac
    
    # only print if variable has a value
    if [ -n "$var_value" ]; then
      print_item "$var_name" "$var_value"
    fi
  done
}

get_path_entries() {
  [ -n "${PATH:-}" ] || return

  print_item "PATH entries" ""

  _seen_file=$(mktemp)

  printf '%s' "$PATH" | tr ':' '\n' | while IFS= read -r path_entry; do
    [ -n "$path_entry" ] || continue

    _dup=""
    if grep -qxF -- "$path_entry" "$_seen_file" 2>/dev/null; then
      _dup=" ${FG_YELLOW}(duplicate entry)${STYLE_RESET}"
    fi
    printf '%s\n' "$path_entry" >> "$_seen_file"

    if [ -d "$path_entry" ]; then
      printf "   ${FG_GREEN}✓${STYLE_RESET} %s%b\n" "$path_entry" "$_dup"
    else
      printf "   ${FG_RED}×${STYLE_RESET} %s ${FG_RED}(not found)${STYLE_RESET}%b\n" "$path_entry" "$_dup"
    fi
  done

  rm -f "$_seen_file"
}

output_json() {
  if [ "$OUTPUT_FORMAT" = "json" ]; then
    echo '{"message": "JSON output is not fully implemented yet"}'
    exit $EXIT_SUCCESS
  fi
}

is_sourced() {
  if [ -n "${BASH_VERSION:-}" ]; then
    [ "${BASH_SOURCE[0]}" != "$0" ]
  elif [ -n "${ZSH_VERSION:-}" ]; then
    [ "$ZSH_EVAL_CONTEXT" = "toplevel:file" ] || [ "$ZSH_EVAL_CONTEXT" = "file" ]
  else
    false
  fi
}

main() {
  # parse command-line arguments
  parse_args "$@" || return $?

  # initialize styling based on terminal capabilities
  init_styling || return $?

  info "Starting shell diagnostics"
  print "\n"

  debug "DRY_RUN: $DRY_RUN FORCE: $FORCE SILENT: $SILENT VERBOSE: $VERBOSE USE_COLOR: $USE_COLOR"

  # handle JSON output if requested
  [[ "$OUTPUT_FORMAT" = "json" ]] && output_json

  # print report header
  print_report_header

  # collect and display shell information
  get_shell_information

  # collect and display user environment
  get_user_environment

  # collect and display system information
  get_system_information

  # collect and display terminal information
  get_terminal_information

  # collect and display path and environment variables
  get_path_and_environment

  # collect and display shell capabilities
  get_shell_capabilities

  # print report footer
  print_report_footer

  print "\n"
  success "Shell diagnostics completed"

  return $EXIT_SUCCESS
}

if ! is_sourced; then
  # execute main function with all arguments
  main "$@"

  # exit with the status of the main function
  exit $?
fi

## eof
