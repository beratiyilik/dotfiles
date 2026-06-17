# Shell Scripting Standards and Best Practices

## Header Comment Template (REQUIRED)

```sh
#!/bin/sh
# $DOTFILES_DIR/lib/script_name.sh        # sourced libraries
# $DOTFILES_DIR/scripts/script_name.sh    # executable scripts
#
# Description:
#   Brief summary of what this script does.
#
# Usage:
#   Provide basic usage instructions or examples here.
#   For example:
#     script_name.sh [options]
#
# Options:
#   -h, --help       Describe what help or usage outputs do
#   -v, --verbose    Describe how verbosity changes script output
#
# Dependencies:
#   - List required commands or external tools (e.g., git, curl, jq).
#   - Note if certain shells, interpreters, or libraries are expected.
#
# Environment Variables:
#   - Explain any environment variables that must be set beforehand,
#     or that this script will read/update.
#   - For instance, MY_ENV_VAR, PATH modifications, etc.
#
# Required Predefined Variables:
#   - For instance, COLOR_ERROR, COLOR_SUCCESS, etc., if you rely on
#     external color/formatting definitions from a broader dotfiles library.
#
# Return Codes:
#   0   - Success
#   10  - Generic or usage error
#   20  - Dependency not found
#   ... (and so on)
#
# CAUTION:
#   - List any known caveats or side effects, such as permanent file changes,
#     network calls, or the need to source the script rather than execute it.
#   - Include disclaimers about system or environment modifications.
```

## Complete Script Template Example

```sh
#!/usr/bin/env bash
# or #!/usr/bin/env zsh
# $DOTFILES_DIR/lib/script_name.sh        # sourced libraries
# $DOTFILES_DIR/scripts/script_name.sh    # executable scripts
#
# Description:
#   A template script demonstrating standardized shell scripting practices.
#   Provides structured logging, argument parsing, and file processing with
#   emphasis on safety, portability, and maintainability.
#
# Usage:
#   script_name.sh [OPTIONS] <target>
#
# Options:
#   --config=FILE      Specify configuration file to source
#   --verbose, -v      Enable verbose logging
#   --help, -h         Display usage information
#
# Examples:
#   script_name.sh --config=myconfig.cfg data.txt
#   script_name.sh --verbose input.csv
#
# Dependencies:
#   - bash (v4+ or zsh if modified), mktemp, date, etc.
#   - Tools available by default on most Unix-like systems.
#
# Environment Variables:
#   - None required by default; user may specify a custom config file
#     via --config=FILE
#
# Return Codes:
#   0  - Success
#   1  - General failure
#   2  - Invalid arguments or missing input file
#   (See constants in the script body for more.)
#
# CAUTION:
#   - Uses 'set -euo pipefail' to exit immediately on errors or undefined variables.
#   - Automatically removes a temporary directory upon script exit (cleanup function).
#   - Logging is written to stderr. Adjust as necessary for your environment.


# exit immediately if a command exits with non-zero status (-e)
set -o errexit
# treat unset variables as an error (-u)
set -o nounset
# exit if any command in a pipeline fails (-o pipefail)
set -o pipefail
# restrict field separators to newline and tab for safety
IFS=$'\n\t'

# constants
readonly VERSION="1.0.0"
readonly SCRIPT_NAME=$(basename "$0")
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly EXIT_INVALID_ARGS=2
readonly TEMP_DIR=$(mktemp -d "/tmp/${SCRIPT_NAME}.XXXXXX")

# default configuration
config_file=""
verbose=false
target=""

# cleanup function
cleanup() {
  local exit_code=$1

  # remove temporary files
  if [[ -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi

  # log exit information if not successful
  if [[ $exit_code -ne 0 ]]; then
    log_error "Script terminated with exit code $exit_code"
  fi

  exit "$exit_code"
}

# set up trap to call cleanup on exit
trap 'cleanup $?' EXIT INT TERM

# logging functions
log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date +"%Y-%m-%dT%H:%M:%S")
  printf "[%s] [%s] %s\n" "$timestamp" "$level" "$message" >&2
}

log_debug() { [[ "$verbose" == true ]] && log "DEBUG" "$1"; }
log_info() { log "INFO" "$1"; }
log_warn() { log "WARNING" "$1"; }
log_error() { log "ERROR" "$1"; }
log_success() { log "SUCCESS" "$1"; }

# display help information
show_help() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] <target>

A template script demonstrating shell scripting standards and best practices.

Options:
  --config=FILE     Specify configuration file
  --verbose, -v     Enable verbose output
  --help, -h        Display this help message and exit

Examples:
  $SCRIPT_NAME --config=myconfig.cfg data.txt
  $SCRIPT_NAME --verbose input.csv

Version: $VERSION
EOF
}

# parse command line arguments
parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --config=*)
        config_file="${1#*=}"
        if [[ ! -f "$config_file" ]]; then
          log_error "Configuration file '$config_file' not found"
          return $EXIT_INVALID_ARGS
        fi
        ;;
      --verbose|-v)
        verbose=true
        log_debug "Verbose mode enabled"
        ;;
      --help|-h)
        show_help
        exit $EXIT_SUCCESS
        ;;
      --*|-*)
        log_error "Unknown option: $1"
        show_help
        return $EXIT_INVALID_ARGS
        ;;
      *)
        if [[ -z "$target" ]]; then
          target="$1"
        else
          log_error "Too many arguments"
          show_help
          return $EXIT_INVALID_ARGS
        fi
        ;;
    esac
    shift
  done

  # validate required arguments
  if [[ -z "$target" ]]; then
    log_error "Missing required target argument"
    show_help
    return $EXIT_INVALID_ARGS
  fi

  # validate target
  if [[ ! -f "$target" ]]; then
    log_error "Target file '$target' not found or not readable"
    return $EXIT_INVALID_ARGS
  }

  return $EXIT_SUCCESS
}

# process the target file
process_file() {
  local file="$1"
  local line_count=0
  local start_time
  local end_time
  local duration

  log_info "Processing file: $file"
  start_time=$(date +%s)

  # example processing - count lines
  if [[ -f "$file" ]]; then
    # efficient way to count lines without spawning a subshell
    mapfile -t lines < "$file"
    line_count=${#lines[@]}

    log_info "File contains $line_count lines"

    # example: process each line
    for line in "${lines[@]}"; do
      log_debug "Processing line: $line"
      # do something with each line
    done
  else
    log_error "Failed to read file: $file"
    return $EXIT_FAILURE
  fi

  end_time=$(date +%s)
  duration=$((end_time - start_time))
  log_success "File processing completed in $duration seconds"

  return $EXIT_SUCCESS
}

# main function
main() {
  log_info "Starting $SCRIPT_NAME v$VERSION"
  log_info "Current Date and Time (UTC): $(date -u +"%Y-%m-%d %H:%M:%S")"

  # parse and process arguments
  parse_args "$@" || return $?

  # load configuration if specified
  if [[ -n "$config_file" ]]; then
    log_info "Loading configuration from: $config_file"
    # shellcheck source=/dev/null
    source "$config_file" || {
      log_error "Failed to load configuration"
      return $EXIT_FAILURE
    }
  fi

  # process target file
  process_file "$target" || return $?

  log_success "$SCRIPT_NAME completed successfully"
  return $EXIT_SUCCESS
}

# execute main function with all arguments
main "$@"

# exit with the status of the main function
exit $?
```
