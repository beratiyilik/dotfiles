# shellcheck shell=bash
# Sourced by .zshrc / .bashrc. Self-contained: defines its own colours and has
# no dependency on the rest of the repo, so it also works sourced on its own.
#
# =============================================================================
# aws.sh — AWS CLI profile manager (Bash + Zsh)
#
# Switches/sets AWS profiles by EXPORTING credentials and region into the
# current shell (incl. assume-role + MFA), so this must be sourced — a separate
# process cannot mutate the parent shell's environment.
#
# Interface (aliases): awsm (manager), awssp (switch+assume), awsset (set
# default), awsst (status), awstest (verify), awsla / awslp (list).
#
# Dependencies: aws (CLI v2 preferred); jq (optional). Bash/Zsh for completion.
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

# printf-based line printer (replaces non-portable `echo -e`)
_aws_pf() { printf '%b\n' "$*"; }

# ----------------------------------------------------------------------- LIST

_awsListAll() {
    local file="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"
    if [[ ! -f "$file" ]]; then
        _aws_pf "${COLOR_ERROR}Error:${STYLE_RESET} Credentials file not found at ${FG_YELLOW}${file}${STYLE_RESET}" >&2
        return 1
    fi
    grep -E '^\[.*\]' "$file"
}

_awsListProfile() {
    local file="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
    if [[ ! -f "$file" ]]; then
        _aws_pf "${COLOR_ERROR}Error:${STYLE_RESET} Profile file not found at ${FG_YELLOW}${file}${STYLE_RESET}" >&2
        return 1
    fi
    while read -r line; do
        [[ $line == "["* ]] && printf '%s\n' "$line"
    done <"$file"
}

# --------------------------------------------------------------- SWITCH / SET

# switch profile by exporting all credential env vars (assume-role aware)
_awsSwitchProfile() {
    local usage="${STYLE_BOLD}${FG_CYAN}Usage:${STYLE_RESET} ${STYLE_BOLD}awssp${STYLE_RESET} ${FG_MAGENTA}<profile>${STYLE_RESET}"
    if ! command -v aws &>/dev/null; then
        _aws_pf "${COLOR_ERROR}Error:${STYLE_RESET} AWS CLI is not installed or not on PATH." >&2
        return 1
    fi
    if [[ -z "$1" ]]; then
        _aws_pf "$usage" >&2
        return 1
    fi

    local profileToUse="$1"
    local exists role_arn mfa_serial source_profile JSON

    exists=$(aws configure get aws_access_key_id --profile "$profileToUse" 2>/dev/null)
    role_arn=$(aws configure get role_arn --profile "$profileToUse" 2>/dev/null)

    if [[ -z "$exists" && -z "$role_arn" ]]; then
        _aws_pf "${COLOR_ERROR}Error:${STYLE_RESET} Profile ${FG_YELLOW}${profileToUse}${STYLE_RESET} not found or missing credentials." >&2
        return 1
    fi

    local use_jq="true"
    if ! command -v jq &>/dev/null; then
        _aws_pf "${COLOR_WARNING}Warning:${STYLE_RESET} 'jq' not found; using AWS CLI --query instead."
        use_jq="false"
    fi

    if [[ -n "$role_arn" ]]; then
        mfa_serial=$(aws configure get mfa_serial --profile "$profileToUse" 2>/dev/null)
        source_profile=$(aws configure get source_profile --profile "$profileToUse" 2>/dev/null)
        local effectiveProfile="${source_profile:-$profileToUse}"

        local mfa_token=""
        if [[ -n "$mfa_serial" ]]; then
            printf '%b' "${FG_YELLOW}Enter MFA token for ${mfa_serial}: ${STYLE_RESET}"
            read -r mfa_token
        fi

        _aws_pf "${FG_YELLOW}Assuming role ${role_arn} using profile ${effectiveProfile}...${STYLE_RESET}"

        # build the argument list in a Bash/Zsh-compatible way
        local cmd_args
        if [[ -n "${ZSH_VERSION:-}" ]]; then
            cmd_args=("--profile=$effectiveProfile" "--role-arn" "$role_arn" "--role-session-name" "$USER-$(date +%s)")
        elif [[ -n "${BASH_VERSION:-}" ]]; then
            cmd_args=(--profile="$effectiveProfile" --role-arn "$role_arn" --role-session-name "$USER-$(date +%s)")
        else
            _aws_pf "${COLOR_ERROR}Error:${STYLE_RESET} Unsupported shell (Bash or Zsh only)." >&2
            return 1
        fi
        if [[ -n "$mfa_serial" && -n "$mfa_token" ]]; then
            cmd_args+=(--serial-number "$mfa_serial" --token-code "$mfa_token")
        fi

        if [[ "$use_jq" == "true" ]]; then
            JSON=$(aws sts assume-role "${cmd_args[@]}" 2>/dev/null)
            if [[ -z "$JSON" ]]; then
                _aws_pf "${COLOR_ERROR}Error:${STYLE_RESET} Failed to assume role. Check permissions or MFA input." >&2
                return 1
            fi
            AWS_ACCESS_KEY_ID="$(printf '%s' "$JSON" | jq -r '.Credentials.AccessKeyId')"
            AWS_SECRET_ACCESS_KEY="$(printf '%s' "$JSON" | jq -r '.Credentials.SecretAccessKey')"
            AWS_SESSION_TOKEN="$(printf '%s' "$JSON" | jq -r '.Credentials.SessionToken')"
            export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
            local expiration
            expiration=$(printf '%s' "$JSON" | jq -r '.Credentials.Expiration')
            _aws_pf "${FG_YELLOW}Temporary credentials expire at: ${expiration}${STYLE_RESET}"
        else
            local readOutput
            readOutput=$(aws sts assume-role "${cmd_args[@]}" --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken,Expiration]' --output text 2>/dev/null)
            if [[ -z "$readOutput" ]]; then
                _aws_pf "${COLOR_ERROR}Error:${STYLE_RESET} Failed to assume role. Check permissions or MFA input." >&2
                return 1
            fi
            local EXPIRATION
            if [[ -n "${ZSH_VERSION:-}" ]]; then
                local -a credentials
                read -r -A credentials <<< "$readOutput"
                AWS_ACCESS_KEY_ID="${credentials[1]}"
                AWS_SECRET_ACCESS_KEY="${credentials[2]}"
                AWS_SESSION_TOKEN="${credentials[3]}"
                EXPIRATION="${credentials[4]}"
            else
                read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN EXPIRATION <<< "$readOutput"
            fi
            export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
            _aws_pf "${FG_YELLOW}Temporary credentials expire at: ${EXPIRATION}${STYLE_RESET}"
        fi
    else
        AWS_ACCESS_KEY_ID="$(aws configure get aws_access_key_id --profile "$profileToUse" 2>/dev/null)"
        AWS_SECRET_ACCESS_KEY="$(aws configure get aws_secret_access_key --profile "$profileToUse" 2>/dev/null)"
        export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
        unset AWS_SESSION_TOKEN
    fi

    export AWS_DEFAULT_PROFILE="$profileToUse" AWS_PROFILE="$profileToUse"

    local region
    region=$(aws configure get region --profile "$profileToUse" 2>/dev/null)
    if [[ -n "$region" ]]; then
        export AWS_DEFAULT_REGION="$region" AWS_REGION="$region"
        _aws_pf "${FG_GREEN}Using region: ${region}${STYLE_RESET}"
    fi

    _aws_pf "${COLOR_SUCCESS}Switched to AWS Profile: ${profileToUse}${STYLE_RESET}"
    aws configure list
}

# set default profile WITHOUT loading credentials into the environment
_awsSetProfile() {
    local usage="${STYLE_BOLD}${FG_CYAN}Usage:${STYLE_RESET} ${STYLE_BOLD}awsset${STYLE_RESET} ${FG_MAGENTA}<profile>${STYLE_RESET}"
    if [[ -z "$1" ]]; then
        _aws_pf "$usage" >&2
        return 1
    fi
    local profileToSet="$1"
    if ! aws configure list-profiles 2>/dev/null | grep -q "^${profileToSet}\$"; then
        _aws_pf "${COLOR_ERROR}Error:${STYLE_RESET} Profile ${FG_YELLOW}${profileToSet}${STYLE_RESET} does not exist." >&2
        return 1
    fi

    export AWS_DEFAULT_PROFILE="$profileToSet" AWS_PROFILE="$profileToSet"

    local region
    region=$(aws configure get region --profile "$profileToSet" 2>/dev/null)
    if [[ -n "$region" ]]; then
        export AWS_DEFAULT_REGION="$region" AWS_REGION="$region"
        _aws_pf "${FG_GREEN}Using region: ${region}${STYLE_RESET}"
    fi

    printf '%s\n' "Switched to AWS Profile: $profileToSet"
    printf '%s\n' "Credentials were NOT exported (use 'aws-vault' or rely on AWS_PROFILE)."
    printf '%s\n' "  aws-vault exec $profileToSet -- aws s3 ls"
    printf '%s\n' "  aws s3 ls   # uses AWS_PROFILE=$profileToSet"
}

# -------------------------------------------------------------- STATUS / TEST

_awsStatus() {
    _aws_pf "${FG_BLUE}=== AWS Profile Status ===${STYLE_RESET}"
    local current_profile="${AWS_PROFILE:-${AWS_DEFAULT_PROFILE:-None}}"
    local region="${AWS_REGION:-${AWS_DEFAULT_REGION:-None}}"
    _aws_pf "${FG_GREEN}Current Profile: ${current_profile}${STYLE_RESET}"
    _aws_pf "${FG_GREEN}Current Region: ${region}${STYLE_RESET}"

    if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]]; then
        _aws_pf "${FG_GREEN}Credentials: Active${STYLE_RESET}"
        if [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
            _aws_pf "${FG_YELLOW}Status: Using temporary credentials${STYLE_RESET}"
            if [[ "$current_profile" != "None" ]]; then
                _aws_pf "${FG_YELLOW}Check expiry with: aws sts get-caller-identity${STYLE_RESET}"
            fi
        else
            _aws_pf "${FG_GREEN}Status: Using permanent credentials${STYLE_RESET}"
        fi
    else
        _aws_pf "${FG_YELLOW}Credentials: Not set in environment${STYLE_RESET}"
    fi
}

# verify the active credentials via STS get-caller-identity
_awsTest() {
    _aws_pf "${FG_BLUE}=== Testing AWS Credentials ===${STYLE_RESET}"
    local has_credentials=false status_message=""

    if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]]; then
        _aws_pf "${FG_GREEN}[ok]${STYLE_RESET} Direct credentials (AWS_ACCESS_KEY_ID) found"
        has_credentials=true
    else
        _aws_pf "${FG_YELLOW}[--]${STYLE_RESET} No direct credentials (AWS_ACCESS_KEY_ID)"
        status_message+="- Direct access keys are not set\n"
    fi
    if [[ -n "${AWS_PROFILE:-}" ]]; then
        _aws_pf "${FG_GREEN}[ok]${STYLE_RESET} AWS_PROFILE is set to: ${FG_YELLOW}${AWS_PROFILE}${STYLE_RESET}"
        has_credentials=true
    else
        _aws_pf "${FG_YELLOW}[--]${STYLE_RESET} AWS_PROFILE not set"
        status_message+="- AWS_PROFILE is not set\n"
    fi
    if [[ -n "${AWS_DEFAULT_PROFILE:-}" ]]; then
        _aws_pf "${FG_GREEN}[ok]${STYLE_RESET} AWS_DEFAULT_PROFILE is set to: ${FG_YELLOW}${AWS_DEFAULT_PROFILE}${STYLE_RESET}"
        has_credentials=true
    else
        _aws_pf "${FG_YELLOW}[--]${STYLE_RESET} AWS_DEFAULT_PROFILE not set"
        status_message+="- AWS_DEFAULT_PROFILE is not set\n"
    fi

    if [[ "$has_credentials" == "false" ]]; then
        _aws_pf "\n${COLOR_ERROR}Error:${STYLE_RESET} No AWS credentials or profiles found in environment." >&2
        _aws_pf "${FG_RED}Missing:${STYLE_RESET}" >&2
        _aws_pf "$status_message" >&2
        _aws_pf "${FG_YELLOW}Set one first with awssp or awsset.${STYLE_RESET}" >&2
        return 1
    fi

    _aws_pf "\n${FG_YELLOW}Calling AWS STS to verify identity...${STYLE_RESET}"
    local output
    if ! output=$(aws sts get-caller-identity 2>&1); then
        _aws_pf "${FG_RED}Failed to get caller identity:${STYLE_RESET}" >&2
        _aws_pf "${FG_RED}${output}${STYLE_RESET}" >&2
        return 1
    fi

    _aws_pf "${FG_GREEN}Authentication successful!${STYLE_RESET}"
    _aws_pf "${FG_BLUE}Identity Information:${STYLE_RESET}"
    printf '%s\n' "$output" | sed 's/^/    /'

    local account_id arn username
    account_id=$(printf '%s' "$output" | grep -o '"Account": "[0-9]*"' | cut -d'"' -f4)
    arn=$(printf '%s' "$output" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)
    username=$(printf '%s' "$arn" | awk -F'/' '{print $NF}')

    printf '\n'
    _aws_pf "${FG_GREEN}Summary:${STYLE_RESET}"
    _aws_pf "  Account ID: ${FG_YELLOW}${account_id}${STYLE_RESET}"
    if [[ "$arn" == *"assumed-role"* ]]; then
        local role
        role=$(printf '%s' "$arn" | awk -F'/' '{print $(NF-1)}')
        _aws_pf "  Role: ${FG_YELLOW}${role}${STYLE_RESET}"
        _aws_pf "  Session: ${FG_YELLOW}${username}${STYLE_RESET}"
    else
        _aws_pf "  User: ${FG_YELLOW}${username}${STYLE_RESET}"
    fi
    _aws_pf "  Local User: ${FG_YELLOW}$(whoami)${STYLE_RESET}"
    _aws_pf "  Timestamp: ${FG_YELLOW}$(date -u '+%Y-%m-%d %H:%M:%S UTC')${STYLE_RESET}"
    [[ -n "${AWS_SESSION_TOKEN:-}" ]] && _aws_pf "${FG_YELLOW}Note: using temporary credentials.${STYLE_RESET}"
    return 0
}

# -------------------------------------------------------------------- MANAGER

_AWS_MANAGER_USAGE="$(cat <<EOF
${STYLE_BOLD}${FG_CYAN}USAGE:${STYLE_RESET}
  ${STYLE_BOLD}awsm${STYLE_RESET} ${FG_YELLOW}[options]${STYLE_RESET}

${STYLE_BOLD}${FG_CYAN}OPTIONS:${STYLE_RESET}
  ${FG_YELLOW}-la, --list-all${STYLE_RESET}           List all AWS credential profiles
  ${FG_YELLOW}-lp, --list-profile${STYLE_RESET}       List all AWS config profiles
  ${FG_YELLOW}-sp, --switch-profile${STYLE_RESET}     Switch to a profile (export temp credentials)
  ${FG_YELLOW}-s, --set, --set-profile${STYLE_RESET}  Set AWS_DEFAULT_PROFILE / AWS_PROFILE
  ${FG_YELLOW}-st, --status${STYLE_RESET}             Display current AWS profile status
  ${FG_YELLOW}-t, --test${STYLE_RESET}                Verify credentials via STS get-caller-identity
  ${FG_YELLOW}-h, --help${STYLE_RESET}                Show this help message

${STYLE_BOLD}${FG_CYAN}EXAMPLES:${STYLE_RESET}
  ${STYLE_BOLD}awsm -la${STYLE_RESET}               List all credential profiles
  ${STYLE_BOLD}awsm -sp${STYLE_RESET} ${FG_MAGENTA}my-profile${STYLE_RESET}    Switch to profile
  ${STYLE_BOLD}awsm -s${STYLE_RESET} ${FG_MAGENTA}my-profile${STYLE_RESET}     Set default profile
  ${STYLE_BOLD}awsm -st${STYLE_RESET}               Show status
  ${STYLE_BOLD}awsm -t${STYLE_RESET}                Test credentials
EOF
)"

_awsManager() {
    if [[ $# -eq 0 ]]; then
        _aws_pf "$_AWS_MANAGER_USAGE"
        return 1
    fi
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -la|--list-all)     _awsListAll;     return 0 ;;
            -lp|--list-profile) _awsListProfile; return 0 ;;
            -sp|--switch-profile)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then _awsSwitchProfile "$2"; shift
                else _aws_pf "${COLOR_ERROR}Error:${STYLE_RESET} Missing profile after ${FG_YELLOW}$1${STYLE_RESET}." >&2; _aws_pf "$_AWS_MANAGER_USAGE" >&2; return 1; fi
                ;;
            -s|--set|--set-profile)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then _awsSetProfile "$2"; shift
                else _aws_pf "${COLOR_ERROR}Error:${STYLE_RESET} Missing profile after ${FG_YELLOW}$1${STYLE_RESET}." >&2; _aws_pf "$_AWS_MANAGER_USAGE" >&2; return 1; fi
                ;;
            -st|--status) _awsStatus ;;
            -t|--test)    _awsTest ;;
            -h|--help)    _aws_pf "$_AWS_MANAGER_USAGE" ;;
            *) _aws_pf "${COLOR_ERROR}Error:${STYLE_RESET} Unknown option: ${FG_YELLOW}$1${STYLE_RESET}" >&2; _aws_pf "$_AWS_MANAGER_USAGE" >&2; return 1 ;;
        esac
        shift
    done
    return 0
}

# ----------------------------------------------------------------- COMPLETION

_awsCompletionList() {
    local credentials_file="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"
    local config_file="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
    {
        [[ -f "$credentials_file" ]] && grep -E '^\[.*\]' "$credentials_file" | sed -E 's/^\[(.*)\]$/\1/'
        if [[ -f "$config_file" ]]; then
            grep -E '^\[profile .*\]' "$config_file" | sed -E 's/^\[profile (.*)\]$/\1/'
            grep -E '^\[default\]' "$config_file" | sed -E 's/^\[(.*)\]$/\1/'
        fi
    } | sort -u
}

_awsmCompletion() {
    local options="-la --list-all -lp --list-profile -sp --switch-profile -s --set --set-profile -st --status -h --help"
    local curw="${COMP_WORDS[COMP_CWORD]}" prev="${COMP_WORDS[COMP_CWORD-1]}"
    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$options" -- "$curw")); return 0
    fi
    case "$prev" in
        -sp|--switch-profile|-s|--set|--set-profile)
            COMPREPLY=($(compgen -W "$(_awsCompletionList)" -- "$curw")) ;;
        *) COMPREPLY=($(compgen -W "$options" -- "$curw")) ;;
    esac
}

_awsProfileCompletion() {
    local curw="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -W "$(_awsCompletionList)" -- "$curw"))
}

# In zsh, bashcompinit lets bash-style `complete` work. compinit is assumed to
# have run already (the interactive shell does it); guarded so standalone
# sourcing never errors — the functions work even if completion is unavailable.
if [ -n "${ZSH_VERSION:-}" ]; then
    autoload -U +X bashcompinit 2>/dev/null && bashcompinit 2>/dev/null
fi
complete -F _awsmCompletion awsm 2>/dev/null
complete -F _awsProfileCompletion awssp 2>/dev/null
complete -F _awsProfileCompletion awsset 2>/dev/null

# -------------------------------------------------------------------- ALIASES

alias awsla="_awsListAll"
alias awslp="_awsListProfile"
alias awssp="_awsSwitchProfile"
alias awsset="_awsSetProfile"
alias awsst="_awsStatus"
alias awstest="_awsTest"
alias awsm="_awsManager"

## eof
