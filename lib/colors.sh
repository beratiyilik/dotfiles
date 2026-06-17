# $DOTFILES_DIR/lib/colors.sh

# guard against multiple inclusion
[ -n "$COLORS_SH_INCLUDED" ] && return 0

# initialize guard
COLORS_SH_INCLUDED=1

#############################################################################
# TERMINAL CAPABILITY CHECK
#############################################################################

TERM_OK=true
USE_COLORS=true
USE_ICONS=true

# check if terminal is capable of displaying colors and icons
if [ -z "${TERM}" ] || [ "${TERM}" = "dumb" ] || [ ! -t 1 ]; then
    TERM_OK=false
    USE_COLORS=false
    USE_ICONS=false
elif command -v tput >/dev/null 2>&1; then
    if ! COLORS=$(tput colors 2>/dev/null) || [ -z "${COLORS}" ] || [ "${COLORS}" -lt 8 ]; then
        USE_COLORS=false
    fi
else
    USE_COLORS=false
fi

# allow override via environment variables
# [ "${NO_COLOR:-}" ] && USE_COLORS=false
# [ "${NO_ICONS:-}" ] && USE_ICONS=false

#############################################################################
# STYLES
#############################################################################

STYLE_BLINK_OFF=""
STYLE_BLINK_ON=""
STYLE_BOLD=""
STYLE_DIM=""
STYLE_RESET=""
STYLE_UNDERLINE=""

if [ "${USE_COLORS}" = true ]; then
    STYLE_BLINK_OFF='\033[25m'
    STYLE_BLINK_ON='\033[5m'
    STYLE_BOLD='\033[1m'
    STYLE_DIM='\033[2m'
    STYLE_RESET='\033[0m'
    STYLE_UNDERLINE='\033[4m'
fi

#############################################################################
# FOREGROUND COLORS (256-COLOR SAFE FALLBACKS)
#############################################################################

define_fg_color() {
    VAR_NAME="$1"
    COLOR_256="$2"
    COLOR_BASIC="$3"
    if [ "${USE_COLORS}" = true ]; then
        if command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || printf 0)" -ge 256 ]; then
            eval "${VAR_NAME}='\\033[38;5;${COLOR_256}m'"
        else
            eval "${VAR_NAME}='\\033[${COLOR_BASIC}m'"
        fi
    else
        eval "${VAR_NAME}=''"
    fi
}

# base colors
define_fg_color FG_BLACK 0 30
define_fg_color FG_BLUE 27 34
define_fg_color FG_CYAN 51 36
define_fg_color FG_GREEN 46 32
define_fg_color FG_MAGENTA 201 35
define_fg_color FG_RED 160 31
define_fg_color FG_WHITE 255 97
define_fg_color FG_YELLOW 226 33

# extended colors
define_fg_color FG_BLUE_BRIGHT 31 34
define_fg_color FG_CYAN_MUTED 66 36
define_fg_color FG_GRAY_MEDIUM 244 37
define_fg_color FG_GREEN_BRIGHT 76 32
define_fg_color FG_LIGHT_BLUE 81 36
define_fg_color FG_LIGHT_GREEN 114 32
define_fg_color FG_ORANGE 208 33
define_fg_color FG_PINK 213 35
define_fg_color FG_PURPLE 93 35
define_fg_color FG_RED_BRIGHT 196 31
define_fg_color FG_YELLOW_BRIGHT 220 33

#############################################################################
# BACKGROUND COLORS
#############################################################################

define_bg_color() {
    VAR_NAME="$1"
    COLOR_256="$2"
    COLOR_BASIC="$3"
    if [ "${USE_COLORS}" = true ]; then
        if command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || printf 0)" -ge 256 ]; then
            eval "${VAR_NAME}='\\033[48;5;${COLOR_256}m'"
        else
            eval "${VAR_NAME}='\\033[${COLOR_BASIC}m'"
        fi
    else
        eval "${VAR_NAME}=''"
    fi
}

define_bg_color BG_BLACK 0 40
define_bg_color BG_BLUE 17 44
define_bg_color BG_CYAN 37 46
define_bg_color BG_GREEN 22 42
define_bg_color BG_MAGENTA 90 45
define_bg_color BG_RED 160 41
define_bg_color BG_WHITE 255 107
define_bg_color BG_YELLOW 178 43

#############################################################################
# SEMANTIC COLOR ALIASES
#############################################################################

COLOR_DEBUG="${FG_CYAN_MUTED}"
COLOR_ERROR="${STYLE_BOLD}${FG_RED_BRIGHT}"
COLOR_HIGHLIGHT="${STYLE_BOLD}${FG_PURPLE}"
COLOR_INFO="${STYLE_BOLD}${FG_BLUE_BRIGHT}"
COLOR_META="${FG_GRAY_MEDIUM}"
COLOR_SUCCESS="${STYLE_BOLD}${FG_GREEN_BRIGHT}"
COLOR_WARNING="${STYLE_BOLD}${FG_YELLOW_BRIGHT}"

#############################################################################
# ICONS
#############################################################################

ICON_ARCHIVE="📦"
ICON_BACKUP="💾"
ICON_BULLET="•"
ICON_CHECK="✓"
ICON_CLOCK="⏱"
ICON_CROSS="✗"
ICON_DEBUG="🔍"
ICON_EXTRACT="📂"
ICON_INFO="ℹ"
ICON_QUESTION="❓"
ICON_USER="👤"
ICON_WARNING="⚠"

if [ "${USE_ICONS}" != true ]; then
    ICON_ARCHIVE="[ZIP]"
    ICON_BACKUP="[BKP]"
    ICON_BULLET="*"
    ICON_CHECK="[OK]"
    ICON_CLOCK="[T]"
    ICON_CROSS="[X]"
    ICON_DEBUG="[DBG]"
    ICON_EXTRACT="[DIR]"
    ICON_INFO="[i]"
    ICON_QUESTION="[?]"
    ICON_USER="[U]"
    ICON_WARNING="[!]"
fi

## eof
