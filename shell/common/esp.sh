# shellcheck shell=bash
# Sourced by .zshrc / .bashrc. Self-contained: defines its own colours and has
# no dependency on the rest of the repo, so it also works sourced on its own.
#
# =============================================================================
# esp.sh — ESP-IDF environment manager for ESP32 / ESP8266 (Bash + Zsh)
#
# Switches between ESP32, ESP8266, and legacy ESP8266 toolchains by EXPORTING
# IDF_PATH and mutating PATH (and sourcing the SDK's export.sh) in the current
# shell — so this must be sourced; a separate process cannot change PATH here.
#
# Interface (aliases): esp (manager), esp32, esp8266, old_esp8266.
#
# SDK locations honour pre-set values (override in vars/local.env or your shell):
#   ESP32_IDF, ESP8266_COMPILER, OLD_ESP8266_SDK
# =============================================================================

# colours: real ESC, honour a pre-set value, default otherwise (self-contained)
STYLE_RESET=${STYLE_RESET:-$'\033[0m'}
STYLE_BOLD=${STYLE_BOLD:-$'\033[1m'}
FG_BLUE=${FG_BLUE:-$'\033[38;5;33m'}
FG_CYAN=${FG_CYAN:-$'\033[38;5;66m'}
FG_GREEN=${FG_GREEN:-$'\033[38;5;76m'}
FG_MAGENTA=${FG_MAGENTA:-$'\033[38;5;201m'}
FG_RED=${FG_RED:-$'\033[38;5;196m'}
FG_YELLOW=${FG_YELLOW:-$'\033[38;5;220m'}
COLOR_ERROR=${COLOR_ERROR:-$FG_RED}
COLOR_SUCCESS=${COLOR_SUCCESS:-$FG_GREEN}
COLOR_WARNING=${COLOR_WARNING:-$FG_YELLOW}

# SDK paths: honour pre-set values so the file stays override-friendly and
# self-contained (no unconditional clobbering of the environment).
export ESP32_IDF="${ESP32_IDF:-$HOME/esp/esp-idf}"
export ESP8266_COMPILER="${ESP8266_COMPILER:-$HOME/esp/xtensa-lx106-elf/bin}"
export OLD_ESP8266_SDK="${OLD_ESP8266_SDK:-$HOME/esp/ESP8266_RTOS_SDK}"

# printf-based line printer (replaces non-portable `echo -e`)
_esp_pf() { printf '%b\n' "$*"; }

# -------------------------------------------------------------------- HELPERS

# remove any $HOME/esp entries from PATH
_clean_esp_paths() {
    local NEW_PATH="" p OIFS="$IFS"
    IFS=":"
    for p in $PATH; do
        IFS="$OIFS"
        [[ "$p" != *"$HOME/esp"* ]] && NEW_PATH="${NEW_PATH:+$NEW_PATH:}$p"
    done
    IFS="$OIFS"
    export PATH="$NEW_PATH"
}

# report whether the current environment matches <env>
_check_esp_env() {
    case "$1" in
        esp32)
            if [[ -n "${IDF_PATH:-}" && "$IDF_PATH" == "$ESP32_IDF" ]]; then
                _esp_pf "${FG_BLUE}${STYLE_BOLD}Current environment:${STYLE_RESET} ${FG_GREEN}ESP32${STYLE_RESET}"
                _esp_pf "  ${FG_CYAN}IDF_PATH:${STYLE_RESET} ${FG_YELLOW}${IDF_PATH}${STYLE_RESET}"
                return 0
            fi ;;
        esp8266)
            if [[ "$PATH" == *"$ESP8266_COMPILER"* ]]; then
                _esp_pf "${FG_BLUE}${STYLE_BOLD}Current environment:${STYLE_RESET} ${FG_GREEN}ESP8266${STYLE_RESET}"
                _esp_pf "  ${FG_CYAN}Compiler:${STYLE_RESET} ${FG_YELLOW}${ESP8266_COMPILER}/xtensa-lx106-elf-gcc${STYLE_RESET}"
                return 0
            fi ;;
        old_esp8266)
            if [[ -n "${IDF_PATH:-}" && "$IDF_PATH" == "$OLD_ESP8266_SDK" ]]; then
                _esp_pf "${FG_BLUE}${STYLE_BOLD}Current environment:${STYLE_RESET} ${FG_GREEN}Old ESP8266 SDK${STYLE_RESET}"
                _esp_pf "  ${FG_CYAN}IDF_PATH:${STYLE_RESET} ${FG_YELLOW}${IDF_PATH}${STYLE_RESET}"
                return 0
            fi ;;
    esac
    return 1
}

# switch to <env>: esp32 | esp8266 | old_esp8266
_esp_switch_env() {
    unset IDF_PATH
    _clean_esp_paths
    local target="$1" switch_status=0
    case "$target" in
        esp32)
            if [[ -d "$ESP32_IDF" ]]; then
                export IDF_PATH="$ESP32_IDF"
                if [[ -f "$ESP32_IDF/export.sh" ]]; then
                    # shellcheck source=/dev/null
                    source "$ESP32_IDF/export.sh" >/dev/null 2>&1 || {
                        _esp_pf "${COLOR_WARNING}Warning:${STYLE_RESET} could not source ESP32 export.sh; basic setup"
                        export PATH="$ESP32_IDF/tools:$PATH"
                    }
                else
                    export PATH="$ESP32_IDF/tools:$PATH"
                fi
                _esp_pf "${COLOR_SUCCESS}${STYLE_BOLD}Switched to ESP32 environment.${STYLE_RESET}"
            else
                _esp_pf "${COLOR_ERROR}Error:${STYLE_RESET} ESP32 IDF not found at ${FG_YELLOW}${ESP32_IDF}${STYLE_RESET}" >&2
                switch_status=1
            fi ;;
        esp8266)
            if [[ -x "$ESP8266_COMPILER/xtensa-lx106-elf-gcc" ]]; then
                export PATH="$ESP8266_COMPILER:$PATH"
                _esp_pf "${COLOR_SUCCESS}${STYLE_BOLD}Switched to ESP8266 environment.${STYLE_RESET}"
            else
                _esp_pf "${COLOR_ERROR}Error:${STYLE_RESET} ESP8266 compiler not found at ${FG_YELLOW}${ESP8266_COMPILER}${STYLE_RESET}" >&2
                switch_status=1
            fi ;;
        old_esp8266)
            if [[ -d "$OLD_ESP8266_SDK" ]]; then
                export IDF_PATH="$OLD_ESP8266_SDK"
                if [[ -f "$OLD_ESP8266_SDK/export.sh" ]]; then
                    # shellcheck source=/dev/null
                    source "$OLD_ESP8266_SDK/export.sh" >/dev/null 2>&1 || {
                        _esp_pf "${COLOR_WARNING}Warning:${STYLE_RESET} could not source Old ESP8266 export.sh; basic setup"
                        export PATH="$OLD_ESP8266_SDK/tools:$PATH"
                    }
                else
                    export PATH="$OLD_ESP8266_SDK/tools:$PATH"
                fi
                _esp_pf "${COLOR_SUCCESS}${STYLE_BOLD}Switched to Old ESP8266 SDK environment.${STYLE_RESET}"
            else
                _esp_pf "${COLOR_ERROR}Error:${STYLE_RESET} Old ESP8266 SDK not found at ${FG_YELLOW}${OLD_ESP8266_SDK}${STYLE_RESET}" >&2
                switch_status=1
            fi ;;
        *)
            _esp_pf "${COLOR_ERROR}Error:${STYLE_RESET} Unknown environment '${FG_YELLOW}${target}${STYLE_RESET}'" >&2
            switch_status=1 ;;
    esac
    return $switch_status
}

# -------------------------------------------------------------------- MANAGER

_ESP_USAGE="$(cat <<EOF
${STYLE_BOLD}${FG_CYAN}USAGE:${STYLE_RESET}
  ${STYLE_BOLD}esp${STYLE_RESET} ${FG_YELLOW}[options]${STYLE_RESET}

${STYLE_BOLD}${FG_CYAN}OPTIONS:${STYLE_RESET}
  ${FG_YELLOW}-s, --set${STYLE_RESET} ${FG_MAGENTA}<32|8266|8266-old>${STYLE_RESET}   Switch to a specific ESP environment
  ${FG_YELLOW}-c, --current${STYLE_RESET}                 Display current environment status
  ${FG_YELLOW}-p, --paths${STYLE_RESET}                   Show configured ESP paths
  ${FG_YELLOW}-h, --help${STYLE_RESET}                    Display this help message

${STYLE_BOLD}${FG_CYAN}EXAMPLES:${STYLE_RESET}
  ${STYLE_BOLD}esp -s${STYLE_RESET} ${FG_MAGENTA}32${STYLE_RESET}         Switch to ESP32 environment
  ${STYLE_BOLD}esp --set${STYLE_RESET} ${FG_MAGENTA}8266${STYLE_RESET}    Switch to ESP8266 environment
  ${STYLE_BOLD}esp -s${STYLE_RESET} ${FG_MAGENTA}8266-old${STYLE_RESET}   Switch to old ESP8266 SDK
  ${STYLE_BOLD}esp -c${STYLE_RESET}            Check current environment
EOF
)"

_display_esp_paths() {
    _esp_pf "${STYLE_BOLD}${FG_CYAN}CONFIGURED ESP PATHS:${STYLE_RESET}"
    _esp_pf "  ${FG_YELLOW}ESP32 IDF:${STYLE_RESET}         ${STYLE_BOLD}${ESP32_IDF}${STYLE_RESET}"
    _esp_pf "  ${FG_YELLOW}ESP8266 Compiler:${STYLE_RESET}  ${STYLE_BOLD}${ESP8266_COMPILER}${STYLE_RESET}"
    _esp_pf "  ${FG_YELLOW}Old ESP8266 SDK:${STYLE_RESET}   ${STYLE_BOLD}${OLD_ESP8266_SDK}${STYLE_RESET}"
}

_esp() {
    if [[ $# -eq 0 ]]; then
        _esp_pf "$_ESP_USAGE"
        return 1
    fi
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--set)
                if [[ -z "$2" ]]; then
                    _esp_pf "${COLOR_ERROR}Error:${STYLE_RESET} Missing argument for '${FG_YELLOW}$1${STYLE_RESET}'." >&2
                    _esp_pf "$_ESP_USAGE" >&2
                    return 1
                fi
                local env
                case "$2" in
                    32)       env="esp32" ;;
                    8266)     env="esp8266" ;;
                    8266-old) env="old_esp8266" ;;
                    *)
                        _esp_pf "${COLOR_ERROR}Error:${STYLE_RESET} Unknown environment '${FG_YELLOW}$2${STYLE_RESET}'" >&2
                        _esp_pf "$_ESP_USAGE" >&2
                        return 1 ;;
                esac
                _esp_switch_env "$env"
                shift ;;
            -c|--current)
                local current_status=1
                _check_esp_env esp32 && current_status=0
                _check_esp_env esp8266 && current_status=0
                _check_esp_env old_esp8266 && current_status=0
                [[ $current_status -ne 0 ]] && _esp_pf "${COLOR_ERROR}Error:${STYLE_RESET} No ESP environment is currently set." ;;
            -p|--paths) _display_esp_paths ;;
            -h|--help)  _esp_pf "$_ESP_USAGE" ;;
            *)
                _esp_pf "${COLOR_ERROR}Error:${STYLE_RESET} Unknown option '${FG_YELLOW}$1${STYLE_RESET}'" >&2
                _esp_pf "$_ESP_USAGE" >&2
                return 1 ;;
        esac
        shift
    done
    return 0
}

# --- COMPLETION  (native zsh compdef / bash complete; guarded for standalone use)

if [ -n "${ZSH_VERSION:-}" ]; then
    _esp_completion() {
        _arguments \
            '(-s --set)'{-s,--set}'[Switch to a specific ESP environment]:environment:(32 8266 8266-old)' \
            '(-c --current)'{-c,--current}'[Display current environment status]' \
            '(-p --paths)'{-p,--paths}'[Show configured ESP paths]' \
            '(-h --help)'{-h,--help}'[Display help message]'
    }
    compdef _esp_completion esp 2>/dev/null
elif [ -n "${BASH_VERSION:-}" ]; then
    _esp_completion() {
        local curw prev
        COMPREPLY=()
        curw="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        if [[ "$prev" == "-s" || "$prev" == "--set" ]]; then
            COMPREPLY=($(compgen -W "32 8266 8266-old" -- "$curw")); return 0
        fi
        COMPREPLY=($(compgen -W "-s --set -c --current -p --paths -h --help" -- "$curw"))
    }
    complete -F _esp_completion esp 2>/dev/null
fi

# -------------------------------------------------------------------- ALIASES

alias esp="_esp"
alias esp32="_esp --set 32"
alias esp8266="_esp --set 8266"
alias old_esp8266="_esp --set 8266-old"

## eof
