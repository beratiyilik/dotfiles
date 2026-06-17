# $DOTFILES_DIR/lib/esp_idf_helpers.sh
#
# Description:
#   ESP-IDF environment manager for ESP32 and ESP8266 platforms. Provides
#   a unified interface to switch between ESP32, modern ESP8266, and legacy
#   ESP8266 development environments. Includes colorized output, path cleanup,
#   environment status checks, and shell auto-completion support.
#
# Usage:
#   source esp_env_manager.sh
#   Then use:
#     - esp       : interactive command-line interface for switching and inspecting environments
#     - esp32     : alias for switching to ESP32 environment
#     - esp8266   : alias for switching to ESP8266 environment
#     - old_esp8266 : alias for switching to old ESP8266 SDK
#
# Options:
#   -s, --set <32|8266|8266-old>   Switch to a specific ESP environment
#   -c, --current                  Display current environment status
#   -p, --paths                    Show all configured ESP paths
#   -h, --help                     Show usage help
#
# Dependencies:
#   - bash or zsh (for autocompletion)
#   - ESP SDKs properly installed in default paths or overridden via variables
#
# Required Predefined Variables:
#   - ESP32_IDF             (Path to ESP32 IDF directory)
#   - ESP8266_COMPILER      (Path to ESP8266 toolchain binaries)
#   - OLD_ESP8266_SDK       (Path to legacy ESP8266 SDK)
#
# Optional Functions:
#   - _get_timestamp        (for logging/debugging if needed)
#
# Caution:
#   - Must be sourced to modify the active shell’s environment.
#   - This script modifies the PATH and IDF_PATH variables.
#   - Color and formatting variables must be defined in your shell environment.

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

# colors
COLOR_ERROR=${COLOR_ERROR:-"${FG_RED}"}
COLOR_INFO=${COLOR_INFO:-"${FG_CYAN}"}
COLOR_SUCCESS=${COLOR_SUCCESS:-"${FG_GREEN}"}
COLOR_WARNING=${COLOR_WARNING:-"${FG_YELLOW}"}

# default paths
export ESP32_IDF="$HOME/esp/esp-idf"
export ESP8266_COMPILER="$HOME/esp/xtensa-lx106-elf/bin"
export OLD_ESP8266_SDK="$HOME/esp/ESP8266_RTOS_SDK"

# export IDF_PATH="$HOME/esp/esp-idf"
# export PATH="$IDF_PATH/tools:$PATH"
# export IDF_PATH="$HOME/esp/ESP8266_RTOS_SDK"
# export PATH="$IDF_PATH/tools:$PATH"
# export PATH="$HOME/esp/xtensa-lx106-elf/bin:$PATH"

# clean up any existing ESP-related paths from PATH
_clean_esp_paths() {
    local NEW_PATH=""
    local p
    local OIFS="$IFS"
    IFS=":"
    for p in $PATH; do
        IFS="$OIFS"
        if [[ "$p" != *"$HOME/esp"* ]]; then
            NEW_PATH="${NEW_PATH:+$NEW_PATH:}$p"
        fi
    done
    export PATH="$NEW_PATH"
}

# check if the current environment is ESP32 or ESP8266
_check_esp_env() {
    local env="$1"
    case "$env" in
        esp32)
            if [[ -n "$IDF_PATH" && "$IDF_PATH" == "$ESP32_IDF" ]]; then
                echo -e "${FG_BLUE}${STYLE_BOLD}Current environment:${STYLE_RESET} ${FG_GREEN}ESP32${STYLE_RESET}"
                echo -e "  ${FG_CYAN}IDF_PATH:${STYLE_RESET} ${FG_YELLOW}$IDF_PATH${STYLE_RESET}"
                return 0
            fi
            ;;
        esp8266)
            if [[ "$PATH" == *"$ESP8266_COMPILER"* ]]; then
                echo -e "${FG_BLUE}${STYLE_BOLD}Current environment:${STYLE_RESET} ${FG_GREEN}ESP8266${STYLE_RESET}"
                echo -e "  ${FG_CYAN}Compiler:${STYLE_RESET} ${FG_YELLOW}$ESP8266_COMPILER/xtensa-lx106-elf-gcc${STYLE_RESET}"
                return 0
            fi
            ;;
        old_esp8266)
            if [[ -n "$IDF_PATH" && "$IDF_PATH" == "$OLD_ESP8266_SDK" ]]; then
                echo -e "${FG_BLUE}${STYLE_BOLD}Current environment:${STYLE_RESET} ${FG_GREEN}Old ESP8266 SDK${STYLE_RESET}"
                echo -e "  ${FG_CYAN}IDF_PATH:${STYLE_RESET} ${FG_YELLOW}$IDF_PATH${STYLE_RESET}"
                return 0
            fi
            ;;
    esac
    return 1
}

_esp_switch_env() {
    unset IDF_PATH
    _clean_esp_paths
    
    local target="$1"
    local switch_status=0
    
    case "$target" in
        esp32)
            if [[ -d "$ESP32_IDF" ]]; then
                export IDF_PATH="$ESP32_IDF"
                if [[ -f "$ESP32_IDF/export.sh" ]]; then
                    source "$ESP32_IDF/export.sh" > /dev/null 2>&1 || {
                        echo -e "${COLOR_WARNING}Warning:${STYLE_RESET} Issues sourcing ESP32 IDF export script, falling back to basic setup"
                        export PATH="$ESP32_IDF/tools:$PATH"
                    }
                else
                    export PATH="$ESP32_IDF/tools:$PATH"
                fi
                echo -e "${COLOR_SUCCESS}${STYLE_BOLD}Switched to ESP32 environment.${STYLE_RESET}"
            else
                echo -e "${COLOR_ERROR}Error:${STYLE_RESET} ESP32 IDF not found at ${FG_YELLOW}$ESP32_IDF${STYLE_RESET}"
                switch_status=1
            fi
            ;;
        esp8266)
            if [[ -x "$ESP8266_COMPILER/xtensa-lx106-elf-gcc" ]]; then
                export PATH="$ESP8266_COMPILER:$PATH"
                echo -e "${COLOR_SUCCESS}${STYLE_BOLD}Switched to ESP8266 environment.${STYLE_RESET}"
            else
                echo -e "${COLOR_ERROR}Error:${STYLE_RESET} ESP8266 compiler not found at ${FG_YELLOW}$ESP8266_COMPILER${STYLE_RESET}"
                switch_status=1
            fi
            ;;
        old_esp8266)
            if [[ -d "$OLD_ESP8266_SDK" ]]; then
                export IDF_PATH="$OLD_ESP8266_SDK"
                if [[ -f "$OLD_ESP8266_SDK/export.sh" ]]; then
                    source "$OLD_ESP8266_SDK/export.sh" > /dev/null 2>&1 || {
                        echo -e "${COLOR_WARNING}Warning:${STYLE_RESET} Issues sourcing Old ESP8266 SDK export script, falling back to basic setup"
                        export PATH="$OLD_ESP8266_SDK/tools:$PATH"
                    }
                else
                    export PATH="$OLD_ESP8266_SDK/tools:$PATH"
                fi
                echo -e "${COLOR_SUCCESS}${STYLE_BOLD}Switched to Old ESP8266 SDK environment.${STYLE_RESET}"
            else
                echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Old ESP8266 SDK not found at ${FG_YELLOW}$OLD_ESP8266_SDK${STYLE_RESET}"
                switch_status=1
            fi
            ;;
        *)
            echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Unknown environment '${FG_YELLOW}$target${STYLE_RESET}'"
            switch_status=1
            ;;
    esac
    
    return $switch_status
}

_ESP_USAGE="$(cat <<EOF
${STYLE_BOLD}${FG_CYAN}USAGE:${STYLE_RESET}
  ${STYLE_BOLD}esp${STYLE_RESET} ${FG_YELLOW}[options]${STYLE_RESET}

${STYLE_BOLD}${FG_CYAN}OPTIONS:${STYLE_RESET}
  ${FG_YELLOW}-s, --set${STYLE_RESET} ${FG_MAGENTA}<32|8266|8266-old>${STYLE_RESET}	Switch to a specific ESP environment
  ${FG_YELLOW}-c, --current${STYLE_RESET}                 Display current environment status
  ${FG_YELLOW}-p, --paths${STYLE_RESET}                   Show configured ESP paths
  ${FG_YELLOW}-h, --help${STYLE_RESET}                    Display this help message

${STYLE_BOLD}${FG_CYAN}EXAMPLES:${STYLE_RESET}
  ${STYLE_BOLD}esp -s${STYLE_RESET} ${FG_MAGENTA}32${STYLE_RESET}         Switch to ESP32 environment
  ${STYLE_BOLD}esp --set${STYLE_RESET} ${FG_MAGENTA}8266${STYLE_RESET}    Switch to ESP8266 environment
  ${STYLE_BOLD}esp -s${STYLE_RESET} ${FG_MAGENTA}8266-old${STYLE_RESET}   Switch to old ESP8266 SDK environment
  ${STYLE_BOLD}esp -c${STYLE_RESET}            Check current environment
EOF
)" # end of _ESP_USAGE

_display_esp_paths() {
    echo -e "$(cat <<EOF
${STYLE_BOLD}${FG_CYAN}CONFIGURED ESP PATHS:${STYLE_RESET}
  ${FG_YELLOW}ESP32 IDF:${STYLE_RESET}         ${STYLE_BOLD}$ESP32_IDF${STYLE_RESET}
  ${FG_YELLOW}ESP8266 Compiler:${STYLE_RESET}  ${STYLE_BOLD}$ESP8266_COMPILER${STYLE_RESET}
  ${FG_YELLOW}Old ESP8266 SDK:${STYLE_RESET}   ${STYLE_BOLD}$OLD_ESP8266_SDK${STYLE_RESET}
EOF
    )" # end of esp paths
}

# main function for ESP environment management
_esp() {
    # if no arguments are provided, display the usage message
    if [[ $# -eq 0 ]]; then
        echo -e "$_ESP_USAGE"
        return 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--set)
                if [[ -z "$2" ]]; then
                    echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Missing argument for option '${FG_YELLOW}$1${STYLE_RESET}'."
                    echo -e "$_ESP_USAGE"
                    return 1
                fi

                local env
                case "$2" in
                    32)
                        env="esp32"
                        ;;
                    8266)
                        env="esp8266"
                        ;;
                    8266-old)
                        env="old_esp8266"
                        ;;
                    *)
                        echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Unknown environment '${FG_YELLOW}$2${STYLE_RESET}'"
                        echo -e "$_ESP_USAGE"
                        return 1
                        ;;
                esac

                _esp_switch_env "$env"
                shift
                ;;
            -c|--current)
                local current_status=1
                _check_esp_env esp32 && current_status=0
                _check_esp_env esp8266 && current_status=0
                _check_esp_env old_esp8266 && current_status=0
                [[ $current_status -ne 0 ]] && echo -e "${COLOR_ERROR}Error:${STYLE_RESET} No ESP environment is currently set."
                ;;
            -p|--paths)
                _display_esp_paths
                ;;
            -h|--help)
                echo -e "$_ESP_USAGE"
                ;;
            *)
                echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Unknown option '${FG_YELLOW}$1${STYLE_RESET}'"
                echo -e "$_ESP_USAGE"
                return 1
                ;;
        esac
        shift
    done

    return 0
}

if [ -n "$ZSH_VERSION" ]; then
    _esp_completion() {
        local curcontext="$curcontext" state line
        typeset -A opt_args
        
        _arguments \
            '(-s --set)'{-s,--set}'[Switch to a specific ESP environment]:environment:(32 8266 8266-old)' \
            '(-c --current)'{-c,--current}'[Display current environment status]' \
            '(-p --paths)'{-p,--paths}'[Show configured ESP paths]' \
            '(-h --help)'{-h,--help}'[Display help message]'
    }
    
    compdef _esp_completion esp
elif [ -n "$BASH_VERSION" ]; then
    _esp_completion() {
        local curw prev opts
        COMPREPLY=()
        curw="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        
        if [[ "$prev" == "-s" || "$prev" == "--set" ]]; then
            COMPREPLY=( $(compgen -W "32 8266 8266-old" -- "$curw") )
            return 0
        fi
        
        opts="-s --set -c --current -p --paths -h --help"
        
        COMPREPLY=( $(compgen -W "${opts}" -- "$curw") )
        return 0
    }

    complete -F _esp_completion esp
fi

# alias get_idf="source $HOME/esp/esp-idf/export.sh"                    # load esp-idf (esp32)
# alias get_lx106="export PATH=$PATH:$HOME/esp/xtensa-lx106-elf/bin"    # load esp8266 compiler
# alias get_idf_old="source $HOME/esp/ESP8266_RTOS_SDK/export.sh"       # load old esp8266 sdk
alias esp="_esp"
alias esp32="_esp --set 32"
alias esp8266="_esp --set 8266"
alias old_esp8266="_esp --set 8266-old"

## eof
