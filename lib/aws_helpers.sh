# $DOTFILES_DIR/lib/aws_helpers.sh
#
# Description:
#   Comprehensive AWS CLI profile manager for shell environments. Provides
#   utilities to list, set, switch, and test AWS CLI profiles and credentials.
#   Includes support for both permanent and temporary credentials (e.g., MFA,
#   assume-role workflows), with colorized feedback and profile-aware region handling.
#
# Usage:
#   Source this file or define the aliases/functions in your shell init file.
#   Primary interface:
#     - awsm     : main command with sub-options
#     - awssp    : switch to profile (assume-role if configured)
#     - awsset   : set default profile (no credentials loaded)
#     - awsst    : display current AWS profile status
#     - awstest  : test and verify current AWS credentials
#
#   Completion:
#     Supports Bash/Zsh auto-completion for profile names and options.
#
# Aliases:
#   - awsla     : List all profiles in credentials file
#   - awslp     : List all profiles in config file
#
# Example:
#   $ awsm -sp dev-admin
#   $ awstest
#
# Dependencies:
#   - AWS CLI (v2 preferred)
#   - jq (optional, improves JSON parsing)
#   - Bash or Zsh (for completion and shell compatibility)

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

#############################################################################
# AWS HELPER FUNCTIONS
#############################################################################

_awsListAll() {
    local credentialFileLocation="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"
    if [[ ! -f "$credentialFileLocation" ]]; then
        echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Credentials file not found at ${FG_YELLOW}$credentialFileLocation${STYLE_RESET}"
        return 1
    fi
    grep -E '^\[.*\]' "$credentialFileLocation"
}

_awsListProfile() {
    local profileFileLocation="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
    if [[ ! -f "$profileFileLocation" ]]; then
        echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Profile file not found at ${FG_YELLOW}$profileFileLocation${STYLE_RESET}"
        return 1
    fi
    while read -r line; do
        if [[ $line == "["* ]]; then
            echo "$line"
        fi
    done <"$profileFileLocation"
}

# switch profile by setting all env vars
_awsSwitchProfile() {
    local usage="${STYLE_BOLD}${FG_CYAN}Usage:${STYLE_RESET} ${STYLE_BOLD}awssp${STYLE_RESET} ${FG_MAGENTA}<profile>${STYLE_RESET}"
    # check that AWS CLI is installed
    if ! command -v aws &>/dev/null; then
        echo -e "${COLOR_ERROR}Error:${STYLE_RESET} AWS CLI is not installed or not found in your PATH."
        return 1
    fi

    if [[ -z "$1" ]]; then
        echo -e "$usage"
        return 1
    fi

    local profileToUse="$1"
    local exists role_arn mfa_serial source_profile JSON

    # get profile information
    exists=$(aws configure get aws_access_key_id --profile "$profileToUse" 2>/dev/null)
    role_arn=$(aws configure get role_arn --profile "$profileToUse" 2>/dev/null)

    if [[ -z "$exists" && -z "$role_arn" ]]; then
        echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Profile ${FG_YELLOW}$profileToUse${STYLE_RESET} not found or missing credentials."
        return 1
    fi

    # check if jq is installed early for better user experience
    local use_jq="true"
    if ! command -v jq &>/dev/null; then
        echo -e "${COLOR_WARNING}Warning:${STYLE_RESET} 'jq' is not found; using AWS CLI --query approach instead."
        use_jq="false"
    fi

    if [[ -n "$role_arn" ]]; then
        mfa_serial=$(aws configure get mfa_serial --profile "$profileToUse" 2>/dev/null)
        source_profile=$(aws configure get source_profile --profile "$profileToUse" 2>/dev/null)

        local effectiveProfile="${source_profile:-$profileToUse}"
        
        local mfa_token=""
        if [[ -n "$mfa_serial" ]]; then
            echo -n -e "${FG_YELLOW}Enter MFA token for $mfa_serial: ${STYLE_RESET}"
            read -r mfa_token
        fi

        echo -e "${FG_YELLOW}Assuming role $role_arn using profile $effectiveProfile...${STYLE_RESET}"

        # handle array creation in both Bash and Zsh compatible way
        local cmd_args
        if [[ -n "$ZSH_VERSION" ]]; then
            cmd_args=("--profile=$effectiveProfile" "--role-arn" "$role_arn" "--role-session-name" "$USER-$(date +%s)")
        elif [[ -n "$BASH_VERSION" ]]; then
            cmd_args=(--profile="$effectiveProfile" --role-arn "$role_arn" --role-session-name "$USER-$(date +%s)")
        else
            echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Unsupported shell. Only Bash and Zsh are supported."
            return 1
        fi
        
        if [[ -n "$mfa_serial" && -n "$mfa_token" ]]; then
            cmd_args+=(--serial-number "$mfa_serial" --token-code "$mfa_token")
        fi

        if [[ "$use_jq" == "true" ]]; then
            JSON=$(aws sts assume-role "${cmd_args[@]}" 2>/dev/null)
            
            if [[ -z "$JSON" ]]; then
                echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Failed to assume role. Check your permissions or MFA input."
                return 1
            fi

            export AWS_ACCESS_KEY_ID="$(echo "$JSON" | jq -r '.Credentials.AccessKeyId')"
            export AWS_SECRET_ACCESS_KEY="$(echo "$JSON" | jq -r '.Credentials.SecretAccessKey')"
            export AWS_SESSION_TOKEN="$(echo "$JSON" | jq -r '.Credentials.SessionToken')"
            
            # display expiration time
            local expiration
            expiration=$(echo "$JSON" | jq -r '.Credentials.Expiration')
            echo -e "${FG_YELLOW}Temporary credentials will expire at: $expiration${STYLE_RESET}"
        else
            local readOutput
            readOutput=$(aws sts assume-role "${cmd_args[@]}" --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken,Expiration]' --output text 2>/dev/null)
            
            if [[ -z "$readOutput" ]]; then
                echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Failed to assume role. Check your permissions or MFA input."
                return 1
            fi

            # read command compatible with both Bash and Zsh
            if [[ -n "$ZSH_VERSION" ]]; then
                # zsh-specific read behavior
                local -a credentials
                read -r -A credentials <<< "$readOutput"
                export AWS_ACCESS_KEY_ID="${credentials[1]}"
                export AWS_SECRET_ACCESS_KEY="${credentials[2]}"
                export AWS_SESSION_TOKEN="${credentials[3]}"
                local EXPIRATION="${credentials[4]}"
            elif [[ -n "$BASH_VERSION" ]]; then
                # bash read behavior
                read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN EXPIRATION <<< "$readOutput"
                export AWS_ACCESS_KEY_ID
                export AWS_SECRET_ACCESS_KEY
                export AWS_SESSION_TOKEN
            else
                echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Unsupported shell. Only Bash and Zsh are supported."
                return 1
            fi
            
            # display expiration time
            echo -e "${FG_YELLOW}Temporary credentials will expire at: $EXPIRATION${STYLE_RESET}"
        fi
    else
        # standard credential approach (no role to assume)
        export AWS_ACCESS_KEY_ID="$(aws configure get aws_access_key_id --profile "$profileToUse" 2>/dev/null)"
        export AWS_SECRET_ACCESS_KEY="$(aws configure get aws_secret_access_key --profile "$profileToUse" 2>/dev/null)"
        unset AWS_SESSION_TOKEN
    fi

    export AWS_DEFAULT_PROFILE="$profileToUse"
    export AWS_PROFILE="$profileToUse"
    
    # set region if available
    local region
    region=$(aws configure get region --profile "$profileToUse" 2>/dev/null)
    if [[ -n "$region" ]]; then
        export AWS_DEFAULT_REGION="$region"
        export AWS_REGION="$region"
        echo -e "${FG_GREEN}Using region: $region${STYLE_RESET}"
    fi
    
    # improved output with color
    echo -e "${COLOR_SUCCESS}Switched to AWS Profile: $profileToUse${STYLE_RESET}"
    aws configure list
}

_awsSetProfile() {
    local usage="${STYLE_BOLD}${FG_CYAN}Usage:${STYLE_RESET} ${STYLE_BOLD}awsset${STYLE_RESET} ${FG_MAGENTA}<profile>${STYLE_RESET}"
    if [[ -z "$1" ]]; then
        echo -e "$usage"
        return 1
    fi
    
    local profileToSet="$1"
    # more efficient check using grep directly on output
    if ! aws configure list-profiles 2>/dev/null | grep -q "^$profileToSet\$"; then
        echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Profile ${FG_YELLOW}$profileToSet${STYLE_RESET} does not exist in your AWS config/credentials."
        return 1
    fi
    
    export AWS_DEFAULT_PROFILE="$profileToSet"
    export AWS_PROFILE="$profileToSet"
    
    # set region if available
    local region
    region=$(aws configure get region --profile "$profileToSet" 2>/dev/null)
    if [[ -n "$region" ]]; then
        export AWS_DEFAULT_REGION="$region"
        export AWS_REGION="$region"
        echo -e "${FG_GREEN}Using region: $region${STYLE_RESET}"
    fi
    
    echo "Switched to AWS Profile: $profileToSet"
    echo "Environment variables with credentials were not set. (Using 'aws configure list' or 'aws-vault' is recommended.)"
    echo "Sample commands to run:"
    echo "$ aws-vault exec $profileToSet -- aws s3 ls"
    echo "$ aws s3 ls   <-- uses AWS_PROFILE=$profileToSet"
}

_awsStatus() {
    
    echo -e "${FG_BLUE}=== AWS Profile Status ===${STYLE_RESET}"
    
    # current profile
    local current_profile="${AWS_PROFILE:-${AWS_DEFAULT_PROFILE:-None}}"
    echo -e "${FG_GREEN}Current Profile: $current_profile${STYLE_RESET}"
    
    # region
    local region="${AWS_REGION:-${AWS_DEFAULT_REGION:-None}}"
    echo -e "${FG_GREEN}Current Region: $region${STYLE_RESET}"
    
    # check for credentials
    if [[ -n "$AWS_ACCESS_KEY_ID" ]]; then
        echo -e "${FG_GREEN}Credentials: Active${STYLE_RESET}"
        
        # display temporary credential status
        if [[ -n "$AWS_SESSION_TOKEN" ]]; then
            echo -e "${FG_YELLOW}Status: Using temporary credentials${STYLE_RESET}"
            
            # get fresh session info if possible
            if [[ -n "$current_profile" && "$current_profile" != "None" ]]; then
                echo -e "${FG_YELLOW}To check expiration time, use: aws sts get-caller-identity${STYLE_RESET}"
            fi
        else
            echo -e "${FG_GREEN}Status: Using permanent credentials${STYLE_RESET}"
        fi
    else
        echo -e "${FG_YELLOW}Credentials: Not set in environment${STYLE_RESET}"
    fi
}

# test AWS credentials using STS get-caller-identity
_awsTest() {
    
    echo -e "${FG_BLUE}=== Testing AWS Credentials ===${STYLE_RESET}"
    
    # check each credential type separately
    local has_credentials=false
    local status_message=""
    
    # check direct credentials
    if [[ -n "$AWS_ACCESS_KEY_ID" ]]; then
        echo -e "${FG_GREEN}✓ Direct credentials (AWS_ACCESS_KEY_ID) found${STYLE_RESET}"
        has_credentials=true
    else
        echo -e "${FG_YELLOW}✗ No direct credentials (AWS_ACCESS_KEY_ID) found${STYLE_RESET}"
        status_message+="- Direct access keys are not set\n"
    fi
    
    # check AWS_PROFILE
    if [[ -n "$AWS_PROFILE" ]]; then
        echo -e "${FG_GREEN}✓ AWS_PROFILE is set to: ${FG_YELLOW}$AWS_PROFILE${STYLE_RESET}"
        has_credentials=true
    else
        echo -e "${FG_YELLOW}✗ AWS_PROFILE not set${STYLE_RESET}"
        status_message+="- AWS_PROFILE is not set\n"
    fi
    
    # check AWS_DEFAULT_PROFILE
    if [[ -n "$AWS_DEFAULT_PROFILE" ]]; then
        echo -e "${FG_GREEN}✓ AWS_DEFAULT_PROFILE is set to: ${FG_YELLOW}$AWS_DEFAULT_PROFILE${STYLE_RESET}"
        has_credentials=true
    else
        echo -e "${FG_YELLOW}✗ AWS_DEFAULT_PROFILE not set${STYLE_RESET}"
        status_message+="- AWS_DEFAULT_PROFILE is not set\n"
    fi
    
    # overall status
    if [[ "$has_credentials" == "false" ]]; then
        echo -e "\n${COLOR_ERROR}Error:${STYLE_RESET} No AWS credentials or profiles found in environment."
        echo -e "${FG_RED}Missing credentials:${STYLE_RESET}"
        echo -e "$status_message"
        echo -e "${FG_YELLOW}Please set AWS credentials or profile first using awssp or awsset.${STYLE_RESET}"
        return 1
    fi
    
    echo -e "\n${FG_YELLOW}Calling AWS STS to verify identity...${STYLE_RESET}"
    
    # rest of the function remains the same
    local output
    if ! output=$(aws sts get-caller-identity 2>&1); then
        echo -e "${FG_RED}Failed to get caller identity:${STYLE_RESET}"
        echo -e "${FG_RED}$output${STYLE_RESET}"
        return 1
    fi
    
    # parse and display account, user ID, and ARN
    echo -e "${FG_GREEN}Authentication successful!${STYLE_RESET}"
    echo -e "${FG_BLUE}Identity Information:${STYLE_RESET}"
    echo "$output" | sed 's/^/    /'
    
    # extract and display account ID and username in a more friendly format
    local account_id=$(echo "$output" | grep -o '"Account": "[0-9]*"' | cut -d'"' -f4)
    local arn=$(echo "$output" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)
    local username=$(echo "$arn" | awk -F'/' '{print $NF}')
    
    echo ""
    echo -e "${FG_GREEN}Summary:${STYLE_RESET}"
    echo -e "  Account ID: ${FG_YELLOW}$account_id${STYLE_RESET}"
    if [[ "$arn" == *"assumed-role"* ]]; then
        local role=$(echo "$arn" | awk -F'/' '{print $(NF-1)}')
        echo -e "  Role: ${FG_YELLOW}$role${STYLE_RESET}"
        echo -e "  Session: ${FG_YELLOW}$username${STYLE_RESET}"
    else
        echo -e "  User: ${FG_YELLOW}$username${STYLE_RESET}"
    fi
    
    # add current user and timestamp dynamically
    echo -e "  Local User: ${FG_YELLOW}$(whoami)${STYLE_RESET}"
    echo -e "  Timestamp: ${FG_YELLOW}$(date -u '+%Y-%m-%d %H:%M:%S UTC')${STYLE_RESET}"
    
    # check for session expiration if using temporary credentials
    if [[ -n "$AWS_SESSION_TOKEN" ]]; then
        echo -e "${FG_YELLOW}Note: You are using temporary credentials.${STYLE_RESET}"
    fi
    
    return 0
}

_AWS_MANAGER_USAGE="$(cat <<EOF
${STYLE_BOLD}${FG_CYAN}USAGE:${STYLE_RESET}
  ${STYLE_BOLD}awsm${STYLE_RESET} ${FG_YELLOW}[options]${STYLE_RESET}
    
${STYLE_BOLD}${FG_CYAN}OPTIONS:${STYLE_RESET}
  ${FG_YELLOW}-la, --list-all${STYLE_RESET}           List all AWS credential profiles
  ${FG_YELLOW}-lp, --list-profile${STYLE_RESET}       List all AWS config profiles
  ${FG_YELLOW}-sp, --switch-profile${STYLE_RESET}     Switch to an AWS profile (with temp credentials)
  ${FG_YELLOW}-s, --set, --set-profile${STYLE_RESET}  Set AWS_DEFAULT_PROFILE and AWS_PROFILE
  ${FG_YELLOW}-st, --status${STYLE_RESET}             Display current AWS profile status
  ${FG_YELLOW}-t, --test${STYLE_RESET}                Test AWS credentials using STS get-caller-identity
  ${FG_YELLOW}-h, --help${STYLE_RESET}                Show this help message

${STYLE_BOLD}${FG_CYAN}EXAMPLES:${STYLE_RESET}
  ${STYLE_BOLD}awsm -la${STYLE_RESET}               List all credential profiles
  ${STYLE_BOLD}awsm -sp${STYLE_RESET} ${FG_MAGENTA}my-profile${STYLE_RESET}    Switch to specified profile
  ${STYLE_BOLD}awsm -s${STYLE_RESET} ${FG_MAGENTA}my-profile${STYLE_RESET}     Set default profile
  ${STYLE_BOLD}awsm -st${STYLE_RESET}               Show current profile status
  ${STYLE_BOLD}awsm -t${STYLE_RESET}                Test current credentials
EOF
)" # end of _AWS_MANAGER_USAGE

# main function to manage AWS profiles
_awsManager() {
    # if no arguments are provided, show help message
    if [[ $# -eq 0 ]]; then
        echo -e "$_AWS_MANAGER_USAGE"
        return 1
    fi

    # parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -la|--list-all)
                _awsListAll
                return 0
                ;;
            -lp|--list-profile)
                _awsListProfile
                return 0
                ;;
            -sp|--switch-profile)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    _awsSwitchProfile "$2"
                    shift
                else
                    echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Missing profile name after ${FG_YELLOW}$1${STYLE_RESET}."
                    echo -e "$_AWS_MANAGER_USAGE"
                    return 1
                fi
                ;;
            -s|--set|--set-profile)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    _awsSetProfile "$2"
                    shift
                else
                    echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Missing profile name after ${FG_YELLOW}$1${STYLE_RESET}."
                    echo -e "$_AWS_MANAGER_USAGE"
                    return 1
                fi
                ;;
            -st|--status)
                _awsStatus
                ;;
            -t|--test)
                _awsTest
                ;;
            -h|--help)
                echo -e "$_AWS_MANAGER_USAGE"
                ;;
            *)
                echo -e "${COLOR_ERROR}Error:${STYLE_RESET} Unknown option: ${FG_YELLOW}$1${STYLE_RESET}"
                echo -e "$_AWS_MANAGER_USAGE"
                return 1
                ;;
        esac
        shift
    done
    return 0
}

_awsCompletionList() {
    local credentials_file="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"
    local config_file="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
    
    # use direct piping for efficiency
    {
        # get profiles from credentials file
        if [[ -f "$credentials_file" ]]; then
            grep -E '^\[.*\]' "$credentials_file" | sed -E 's/^\[(.*)\]$/\1/'
        fi
        
        # get profiles from config file
        if [[ -f "$config_file" ]]; then
            grep -E '^\[profile .*\]' "$config_file" | sed -E 's/^\[profile (.*)\]$/\1/'
            grep -E '^\[default\]' "$config_file" | sed -E 's/^\[(.*)\]$/\1/'
        fi
    } | sort -u
}

_awsmCompletion() {
    local options="-la --list-all -lp --list-profile -sp --switch-profile -s --set --set-profile -st --status -h --help"
    local curw="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$options" -- "$curw"))
        return 0
    fi

    case "$prev" in
        -sp|--switch-profile|-s|--set|--set-profile)
            local profiles
            profiles="$(_awsCompletionList)"
            COMPREPLY=($(compgen -W "$profiles" -- "$curw"))
            ;;
        *)
            COMPREPLY=($(compgen -W "$options" -- "$curw"))
            ;;
    esac
}

_awsProfileCompletion() {
    local curw="${COMP_WORDS[COMP_CWORD]}"
    local profiles
    profiles="$(_awsCompletionList)"
    COMPREPLY=($(compgen -W "$profiles" -- "$curw"))
}

# if zsh available, use zsh-specific completion functions
if [[ -n "$ZSH_VERSION" ]]; then
    # zsh completions
    autoload -U +X compinit && compinit
    autoload -U +X bashcompinit && bashcompinit
fi

# now we can use bash completion functions
complete -F _awsmCompletion awsm
complete -F _awsProfileCompletion awssp
complete -F _awsProfileCompletion awsset

# register aliases
alias awsla="_awsListAll"
alias awslp="_awsListProfile"
alias awssp="_awsSwitchProfile"
alias awsset="_awsSetProfile"
alias awsst="_awsStatus"
alias awstest="_awsTest"
alias awsm="_awsManager"

## eof
