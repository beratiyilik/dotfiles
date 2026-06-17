# =============================================================================
# ai_rename.sh
# =============================================================================
#
# DESCRIPTION
#   Renames a file based on its content using a local Ollama model.
#   Reads the file, sends its content to the model along with a naming
#   convention document, and renames the file to the model's suggestion.
#
# USAGE
#   ai_rename <file> [options]
#
# OPTIONS
#   -n, --dry-run    Preview the suggested name without renaming
#   -m, --model      Ollama model to use (default: qwen2.5-coder:7b)
#   -h, --help       Show help
#
# SUPPORTED FILE TYPES
#   text/*, markdown, source code   — read directly
#   application/pdf                 — requires pdftotext (poppler-utils)
#   .docx                           — requires unzip
#
# DEPENDENCIES
#   curl, jq, file (libmagic)
#   Optional: pdftotext (pdf), unzip (docx)
#
# NAMING CONVENTION
#   Loaded from: $DOTFILES_DIR/docs/FILE_NAMING_CONVENTION.md
#
# OLLAMA API
#   Endpoint: http://localhost:11434/api/generate
#   Model:    qwen2.5-coder:7b (overridable via --model)
#
# INTERNALS
#   All helper functions are prefixed with __ai_rename_ to avoid polluting
#   the global namespace.
#
# SHELL COMPATIBILITY
#   zsh (primary), bash (supported via runtime detection)
#
# =============================================================================

# ---------------------------------------------------------------------------
# config (module-level; _ai_rename reads these as defaults)
# ---------------------------------------------------------------------------
_AI_RENAME_MODEL="${AI_DEFAULT_SMALL_MODEL:-qwen2.5-coder:7b}"
_AI_RENAME_API_URL="${AI_API_URL:-http://localhost:11434/api/generate}"
_FILE_NAMING_CONVENTION_PATH="$DOTFILES_DIR/docs/FILE_NAMING_CONVENTION.md"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

# print usage to stderr
# usage: __ai_rename_usage <model>
__ai_rename_usage() {
    printf "
ai_rename — rename a file based on its content via local Ollama model

Usage:
  ai_rename <file> [options]

Arguments:
  <file>           File to rename (required)

Options:
  -n, --dry-run    Preview new name without renaming
  -m, --model      Ollama model to use (default: %s)
  -h, --help       Show this help

Supported formats:
  text, markdown, source code, pdf (requires pdftotext)

Examples:
  ai_rename ~/Downloads/document.pdf
  ai_rename notes.txt --dry-run
  ai_rename script.sh --model qwen2.5-coder:7b
" "${1:-$_AI_RENAME_MODEL}" >&2
}

# return 0 if $1 is an available command, 1 if not, 2 on usage error
__ai_rename_has_command() {
    [ $# -eq 1 ] && [ -n "$1" ] || return 2
    command -v -- "$1" >/dev/null 2>&1
}

# verify required tools (curl, jq, file) and convention file are present
# returns 1 and prints each missing item if any check fails
# usage: __ai_rename_check_deps <convention_path>
__ai_rename_check_deps() {
    local _convention_path="$1"
    local _missing=0
    local _tool
    for _tool in curl jq file; do
        if ! __ai_rename_has_command "$_tool"; then
            printf "error: required tool not found: %s\n" "$_tool" >&2
            _missing=$((_missing + 1))
        fi
    done
    [ "$_missing" -gt 0 ] && return 1

    [ -f "$_convention_path" ] || {
        printf "error: convention file not found: %s\n" "$_convention_path" >&2
        return 1
    }
}

# extract up to 200 lines (or 3000 chars for docx) of text from $1
# dispatches on MIME type; returns 1 for unsupported types or missing tools
__ai_rename_read_content() {
    local mimetype
    mimetype=$(file --mime-type -b "$1")

    case "$mimetype" in
        text/*)
            head -n 200 "$1"
            ;;
        application/pdf)
            __ai_rename_has_command pdftotext \
                || { printf "error: pdftotext not found — install poppler-utils\n" >&2; return 1; }
            pdftotext "$1" - | head -n 200
            ;;
        application/vnd.openxmlformats-officedocument.wordprocessingml.document|\
        application/zip)
            __ai_rename_has_command unzip \
                || { printf "error: unzip not found\n" >&2; return 1; }
            unzip -p "$1" "word/document.xml" 2>/dev/null \
                | sed 's/<[^>]*>//g' \
                | tr -s ' \n' ' ' \
                | head -c 3000
            ;;
        *)
            printf "error: unsupported file type: %s\n" "$mimetype" >&2
            return 1
            ;;
    esac
}

# send content and extension to the Ollama API
# usage: __ai_rename_request <content> <ext> <model> <url> <convention_path>
# prints a sanitized lowercase kebab-case filename stem to stdout
__ai_rename_request() {
    local _content="$1"
    local _ext="$2"
    local _model="$3"
    local _url="$4"
    local _convention_path="$5"

    local convention
    convention=$(cat "$_convention_path")

    local payload
    payload=$(jq -n \
        --arg model      "$_model" \
        --arg content    "$_content" \
        --arg ext        "$_ext" \
        --arg convention "$convention" \
        '{
            model: $model,
            system: (
              "You are a file naming assistant. Follow this naming convention strictly:\n\n"
              + $convention
            ),
            prompt: (
              "Based on the file content below, suggest a filename.\n"
              + "File extension: " + $ext + "\n"
              + "Output ONLY the filename without extension, nothing else.\n\n"
              + "Content:\n" + $content + "\n"
              + "/no_think"
            ),
            stream: false,
            think: false,
            options: { temperature: 0, num_predict: 30, num_ctx: 8192 }
          }')

    local resp code body err result
    resp=$(curl -s -w '\n%{http_code}' "$_url" -d "$payload") || {
        printf "error: request to %s failed\n" "$_url" >&2; return 1
    }
    code="${resp##*$'\n'}"
    body="${resp%$'\n'*}"
    [ "$code" = 200 ] || {
        printf "error: HTTP %s from model endpoint\n" "$code" >&2; return 1
    }
    err=$(printf '%s' "$body" | jq -r '.error // empty')
    [ -z "$err" ] || { printf "error: model: %s\n" "$err" >&2; return 1; }

    result=$(printf '%s' "$body" \
        | jq -r '.response // empty' \
        | tr -d '\n' \
        | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9_]/_/g' \
        | sed 's/__*/_/g' \
        | sed 's/^_//;s/_$//')

    [ -z "$result" ] && { printf "error: empty response from model\n" >&2; return 1; }
    printf '%s' "$result"
}

# start a braille-frame spinner in a background subshell
# PID stored in _AI_RENAME_SPINNER_PID — always pair with __ai_rename_spinner_stop
# usage: __ai_rename_spinner_start [message]
__ai_rename_spinner_start() {
    [ -n "${ZSH_VERSION:-}" ] && setopt NO_MONITOR 2>/dev/null || true
    local msg="${1:-Working...}"
    local -r frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    (
        while true; do
            i=1
            while [ "$i" -le "${#frames}" ]; do
                printf "\r%s %s" "$(printf '%s' "$frames" | cut -c"$i")" "$msg"
                sleep 0.08
                i=$((i + 1))
            done
        done
    ) 2>/dev/null &
    _AI_RENAME_SPINNER_PID=$!
    disown "$_AI_RENAME_SPINNER_PID" 2>/dev/null || true
}

# kill the spinner started by __ai_rename_spinner_start and clear the line
__ai_rename_spinner_stop() {
    [ -n "${_AI_RENAME_SPINNER_PID:-}" ] || return 0
    kill "$_AI_RENAME_SPINNER_PID" 2>/dev/null || true
    _AI_RENAME_SPINNER_PID=""
    printf "\r                    \r"
}

# =============================================================================
# main
# =============================================================================

_ai_rename() {
    local _model="$_AI_RENAME_MODEL"
    local _url="$_AI_RENAME_API_URL"
    local _convention_path="$_FILE_NAMING_CONVENTION_PATH"
    local filepath="" dry_run=0

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)    __ai_rename_usage "$_model"; return 0 ;;
            -n|--dry-run) dry_run=1; shift ;;
            -m|--model)
                [ $# -lt 2 ] && { printf "error: --model requires a value\n" >&2; return 1; }
                _model="$2"; shift 2
                ;;
            -*)
                printf "error: unknown option '%s'\n" "$1" >&2
                printf "hint:  run 'ai_rename --help' for usage\n" >&2
                return 1
                ;;
            *)
                [ -n "$filepath" ] && { printf "error: too many arguments\n" >&2; return 1; }
                filepath="$1"; shift
                ;;
        esac
    done

    [ -z "$filepath" ] && { __ai_rename_usage "$_model"; return 1; }
    [ -f "$filepath" ] || { printf "error: file not found: %s\n" "$filepath" >&2; return 1; }
    __ai_rename_check_deps "$_convention_path" || return 1

    local base dir ext new_name new_path
    base=$(basename "$filepath")
    dir=$(dirname "$filepath")
    ext="${base##*.}"
    [ "$ext" = "$base" ] && ext=""

    local content
    content=$(__ai_rename_read_content "$filepath") || return 1

    __ai_rename_spinner_start "Generating filename..."
    new_name=$(__ai_rename_request "$content" "$ext" "$_model" "$_url" "$_convention_path")
    local _rc=$?
    __ai_rename_spinner_stop
    [ "$_rc" -eq 0 ] || return 1

    [ -n "$ext" ] \
        && new_path="${dir}/${new_name}.${ext}" \
        || new_path="${dir}/${new_name}"

    printf "%s  ->  %s\n" "$base" "${new_path##*/}"

    if [ "$dry_run" -eq 1 ]; then
        printf "(dry-run, no changes made)\n"
        return 0
    fi

    [ -e "$new_path" ] && { printf "error: target already exists: %s\n" "$new_path" >&2; return 1; }
    command mv "$filepath" "$new_path"
}

# =============================================================================
# aliases
# =============================================================================
alias ai_rename="_ai_rename"
alias air="_ai_rename"