# $DOTFILES_DIR/lib/archive_helpers.sh
#
# Description:
#   Utility functions for archiving, extracting, and backing up files.
#   Provides:
#     - _backup  : Create timestamped backups with checksum verification
#     - _pack    : Create tar.gz archives
#     - _extract : Universal extraction of archive files
#     - _vault   : Encrypt/decrypt GPG tar archives
#
# Usage:
#   Source this file in your shell rc / init scripts.
#   Then call functions directly, or use the aliases:
#     bkf   : backup files
#     tgz   : create tar.gz archive
#     extr  : extract any supported archive type
#     vault : encrypt/decrypt GPG tar archives
#
# Dependencies:
#   - tar, gzip, gunzip, zip, unzip, bunzip2, 7z, unrar
#   - sha256sum, shasum, or openssl  (checksum verification)
#   - gpg                            (encryption / decryption)
#
# Compatibility: bash ≥ 3.2, zsh ≥ 5.0
###############################################################################
# CONSTANTS
###############################################################################

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

# semantic colors
COLOR_ERROR=${COLOR_ERROR:-"${FG_RED}"}
COLOR_INFO=${COLOR_INFO:-"${FG_CYAN}"}
COLOR_SUCCESS=${COLOR_SUCCESS:-"${FG_GREEN}"}
COLOR_WARNING=${COLOR_WARNING:-"${FG_YELLOW}"}

# icons
ICON_ARCHIVE=${ICON_ARCHIVE:-"📦"}
ICON_BACKUP=${ICON_BACKUP:-"💾"}
ICON_EXTRACT=${ICON_EXTRACT:-"📤"}
ICON_ENCRYPT=${ICON_ENCRYPT:-"🔒"}
ICON_DECRYPT=${ICON_DECRYPT:-"🔓"}

###############################################################################
# HELPERS — file scope, prefixed, not intended for direct invocation
###############################################################################

# _archive_check_deps <tool> [<tool> ...]
#   Verifies every listed command exists.  Reports all missing ones at once.
_archive_check_deps() {
  local missing=""
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || missing="${missing}  ${tool}\n"
  done
  if [[ -n "$missing" ]]; then
    printf "${COLOR_ERROR}Error:${STYLE_RESET} missing dependencies:\n${missing}" >&2
    return 1
  fi
}

# _archive_ensure_dir <dir>
#   Creates <dir> (including parents) if it does not already exist.
_archive_ensure_dir() {
  local dir="$1"
  [[ -d "$dir" ]] && return 0
  mkdir -p "$dir" || {
    printf "${COLOR_ERROR}Error:${STYLE_RESET} could not create directory '%s'.\n" "$dir" >&2
    return 1
  }
}

###############################################################################
# _backup
###############################################################################

# Creates a timestamped backup of a file or directory with checksum verification.
#
# Usage: bkf <source_path> [<backup_dir>]
#
# Arguments:
#   source_path  File or directory to back up (required).
#   backup_dir   Destination directory (default: current directory).
#
# Examples:
#   bkf ~/.ssh/config
#   bkf ~/projects/app  ~/backups
_backup() {
  local source_path=""
  local backup_dir="."
  local backup_dir_set=0

  _backup_checksum() {
    local filepath="$1"
    local bin args

    if   command -v sha256sum >/dev/null 2>&1; then bin="sha256sum"; args=""
    elif command -v shasum    >/dev/null 2>&1; then bin="shasum";    args="-a 256"
    elif command -v openssl   >/dev/null 2>&1; then bin="openssl";   args="dgst -sha256 -r"
    else
      printf '%s\n' "${COLOR_ERROR}Error:${STYLE_RESET} no checksum tool found (sha256sum / shasum / openssl)." >&2
      return 1
    fi

    if [[ -d "$filepath" ]]; then
      find "$filepath" -type f -print0 \
        | sort -z \
        | xargs -0 $bin $args \
        | awk '{print $1}' \
        | $bin $args \
        | awk '{print $1}'
    else
      $bin $args "$filepath" | awk '{print $1}'
    fi
  }

  # ── parse args ─────────────────────────────────────────────────────────────
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        printf "\n"
        printf "${STYLE_BOLD}bkf${STYLE_RESET} — timestamped backup with checksum verification\n\n"
        printf "${STYLE_BOLD}${FG_CYAN}Usage:${STYLE_RESET}\n"
        printf "  ${STYLE_BOLD}bkf${STYLE_RESET} ${FG_MAGENTA}<source_path>${STYLE_RESET} [${FG_YELLOW}<backup_dir>${STYLE_RESET}]\n"
        printf "  ${STYLE_BOLD}bkf${STYLE_RESET} ${FG_YELLOW}-h, --help${STYLE_RESET}\n\n"
        printf "${STYLE_BOLD}${FG_CYAN}Arguments:${STYLE_RESET}\n"
        printf "  ${FG_MAGENTA}<source_path>${STYLE_RESET}   File or directory to back up (required).\n"
        printf "  ${FG_YELLOW}<backup_dir>${STYLE_RESET}    Destination directory (default: current directory).\n\n"
        printf "${STYLE_BOLD}${FG_CYAN}Examples:${STYLE_RESET}\n"
        printf "  bkf ~/.ssh/config\n"
        printf "  bkf ~/projects/app  ~/backups\n\n"
        return 0
        ;;
      -*)
        printf "${COLOR_ERROR}Error:${STYLE_RESET} unknown option '%s'.\n" "$1" >&2
        printf "${COLOR_INFO}Hint:${STYLE_RESET}  run 'bkf --help' for usage.\n" >&2
        return 1
        ;;
      *)
        if [[ -z "$source_path" ]]; then
          source_path="$1"
        elif [[ "$backup_dir_set" -eq 0 ]]; then
          backup_dir="$1"
          backup_dir_set=1
        else
          printf "${COLOR_ERROR}Error:${STYLE_RESET} too many arguments.\n" >&2
          return 1
        fi
        shift
        ;;
    esac
  done

  # ── validate ───────────────────────────────────────────────────────────────
  if [[ -z "$source_path" ]]; then
    printf "${COLOR_INFO}Usage:${STYLE_RESET} bkf <source_path> [<backup_dir>]\n" >&2
    return 1
  fi
  if [[ ! -e "$source_path" ]]; then
    printf "${COLOR_ERROR}Error:${STYLE_RESET} '%s' does not exist.\n" "$source_path" >&2
    return 1
  fi
  _archive_ensure_dir "$backup_dir" || return 1

  # ── build destination path ─────────────────────────────────────────────────
  local ts base stem ext backup_path
  ts="$(date +"%Y%m%d%H%M%S")"
  base="$(basename "$source_path")"

  if [[ -d "$source_path" ]]; then
    # Directories get no extension suffix.
    stem="$base"
    ext=""
  elif [[ "$base" == .* && "$base" != *.*.* ]]; then
    # Dotfile with no real extension, e.g. .bashrc, .zsh_history
    # (single leading dot, no further dots) — treat the whole name as the stem.
    stem="$base"
    ext=""
  else
    # Strip only the final extension so foo.tar.gz → stem=foo.tar ext=.gz
    stem="${base%.*}"
    ext=".${base##*.}"
  fi

  backup_path="${backup_dir}/${stem}_${ts}_$$${ext}.bak"

  # ── checksum original ──────────────────────────────────────────────────────
  local checksum_original
  checksum_original="$(_backup_checksum "$source_path")" || return 1

  # ── copy ───────────────────────────────────────────────────────────────────
  if [[ -d "$source_path" ]]; then
    cp -a "$source_path" "$backup_path"
  else
    cp -p "$source_path" "$backup_path"
  fi || {
    printf "${COLOR_ERROR}Error:${STYLE_RESET} copy failed.\n" >&2
    return 1
  }

  # ── verify ─────────────────────────────────────────────────────────────────
  local checksum_backup
  checksum_backup="$(_backup_checksum "$backup_path")" || {
    rm -rf "$backup_path"
    return 1
  }

  if [[ "$checksum_original" != "$checksum_backup" ]]; then
    printf "${COLOR_ERROR}Error:${STYLE_RESET} checksum mismatch — backup may be corrupt.\n" >&2
    rm -rf "$backup_path"
    return 1
  fi

  printf "${COLOR_SUCCESS}${ICON_BACKUP} Backup created:${STYLE_RESET} ${FG_CYAN}%s${STYLE_RESET}\n" "$backup_path"
}

###############################################################################
# _pack
###############################################################################

# Creates a tar.gz archive of one or more files/directories.
#
# Usage:
#   tgz <file|dir> [<dest_dir>]
#   tgz <archive_name> <file|dir> [<file|dir> ...]
#
# Arguments:
#   Single source form:
#     file|dir     Source to archive (required).
#     dest_dir     Where to write the archive (default: same directory as source).
#
#   Multi-source form (2+ sources):
#     archive_name Name for the output archive (.tar.gz appended if missing).
#                   NOTE: this name is NOT itself archived.
#     file|dir ...  Sources to include in the archive (2 or more required).
#
# Examples:
#   tgz ~/projects/app
#   tgz ~/projects/app ~/archives
#   tgz mybackup file1.txt file2.txt
#   tgz history_backups_10062026 .zsh_history_*.bak
_pack() {
  emulate -L zsh -o KSH_ARRAYS 2>/dev/null || true
  local args=()

  # ── parse args ─────────────────────────────────────────────────────────────
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        printf "\n"
        printf "${STYLE_BOLD}tgz${STYLE_RESET} — create a tar.gz archive\n\n"
        printf "${STYLE_BOLD}${FG_CYAN}Usage:${STYLE_RESET}\n"
        printf "  ${STYLE_BOLD}tgz${STYLE_RESET} ${FG_MAGENTA}<file|dir>${STYLE_RESET} [${FG_YELLOW}<dest_dir>${STYLE_RESET}]\n"
        printf "  ${STYLE_BOLD}tgz${STYLE_RESET} ${FG_MAGENTA}<archive_name>${STYLE_RESET} ${FG_MAGENTA}<file|dir> [<file|dir> ...]${STYLE_RESET}\n"
        printf "  ${STYLE_BOLD}tgz${STYLE_RESET} ${FG_YELLOW}-h, --help${STYLE_RESET}\n\n"
        printf "${STYLE_BOLD}${FG_CYAN}Arguments:${STYLE_RESET}\n"
        printf "  ${FG_MAGENTA}<file|dir>${STYLE_RESET}      Source to archive (required).\n"
        printf "  ${FG_YELLOW}<dest_dir>${STYLE_RESET}      Destination directory (default: same as source).\n\n"
        printf "  With 2+ sources, the ${FG_MAGENTA}first argument${STYLE_RESET} is the output archive name\n"
        printf "  (.tar.gz appended if missing) and is ${STYLE_BOLD}not${STYLE_RESET} itself archived.\n\n"
        printf "${STYLE_BOLD}${FG_CYAN}Examples:${STYLE_RESET}\n"
        printf "  tgz ~/projects/app\n"
        printf "  tgz ~/projects/app  ~/archives\n"
        printf "  tgz mybackup file1.txt file2.txt\n"
        printf "  tgz history_backups_10062026 .zsh_history_*.bak\n\n"
        return 0
        ;;
      -*)
        printf "${COLOR_ERROR}Error:${STYLE_RESET} unknown option '%s'.\n" "$1" >&2
        printf "${COLOR_INFO}Hint:${STYLE_RESET}  run 'tgz --help' for usage.\n" >&2
        return 1
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  if [[ ${#args[@]} -eq 0 ]]; then
    printf "${COLOR_INFO}Usage:${STYLE_RESET} tgz <file|dir> [<dest_dir>]\n" >&2
    printf "${COLOR_INFO}       ${STYLE_RESET}tgz <archive_name> <file|dir> [<file|dir> ...]\n" >&2
    return 1
  fi

  _archive_check_deps tar || return 1

  # ── multi-source form: first arg is archive name, rest are sources ────────
  if [[ ${#args[@]} -ge 3 || ( ${#args[@]} -eq 2 && -e "${args[0]}" && -e "${args[1]}" ) ]]; then
    local archive_name="${args[0]}"
    local sources=()
    local i
    for (( i = 1; i < ${#args[@]}; i++ )); do
      sources+=("${args[$i]}")
    done
    local src

    for src in "${sources[@]}"; do
      if [[ ! -e "$src" ]]; then
        printf "${COLOR_ERROR}Error:${STYLE_RESET} '%s' is not a valid file or directory.\n" "$src" >&2
        return 1
      fi
    done

    # Strip trailing .tar.gz / .tgz if user already supplied it
    case "$archive_name" in
      *.tar.gz) archive_name="${archive_name%.tar.gz}" ;;
      *.tgz)    archive_name="${archive_name%.tgz}" ;;
    esac

    local archive_path="${archive_name}.tar.gz"

    if ! tar -czf "$archive_path" -- "${sources[@]}"; then
      printf "${COLOR_ERROR}Error:${STYLE_RESET} archive creation failed.\n" >&2
      rm -f "$archive_path"
      return 1
    fi

    printf "${COLOR_SUCCESS}${ICON_ARCHIVE} Created archive:${STYLE_RESET} ${FG_CYAN}%s${STYLE_RESET}\n" "$archive_path"
    return 0
  fi

  # ── single-source form (original behavior) ─────────────────────────────────
  local input="${args[0]}"
  local dest_dir="${args[1]:-}"

  if [[ ! -e "$input" ]]; then
    printf "${COLOR_ERROR}Error:${STYLE_RESET} '%s' is not a valid file or directory.\n" "$input" >&2
    return 1
  fi

  local base input_dir stem archive_path
  base="$(basename "$input")"
  input_dir="$(dirname "$input")"

  if [[ "$base" == .* && "$base" != *.*.* ]]; then
    stem="$base"   # dotfile with no real extension: .zshrc, .vimrc
  else
    stem="${base%.*}"
    [[ -z "$stem" ]] && stem="$base"
  fi

  [[ -z "$dest_dir" ]] && dest_dir="$input_dir"
  _archive_ensure_dir "$dest_dir" || return 1

  archive_path="${dest_dir}/${stem}.tar.gz"

  if ! tar -czf "$archive_path" -C "$input_dir" "$base"; then
    printf "${COLOR_ERROR}Error:${STYLE_RESET} archive creation failed.\n" >&2
    rm -f "$archive_path"
    return 1
  fi

  printf "${COLOR_SUCCESS}${ICON_ARCHIVE} Created archive:${STYLE_RESET} ${FG_CYAN}%s${STYLE_RESET}\n" "$archive_path"
}

###############################################################################
# _extract
###############################################################################

# Extracts any supported archive format.
#
# Usage: extr <archive> [<dest_dir>]
#
# Supported formats: tar.bz2 tbz2 tar.gz tgz tar.xz txz tar bz2 gz zip rar 7z
#
# Arguments:
#   archive    Archive file to extract (required).
#   dest_dir   Where to extract (default: current directory).
#
# Examples:
#   extr archive.tar.gz
#   extr archive.zip  ~/extracted
_extract() {
  local archive=""
  local dest_dir="."

  # ── parse args ─────────────────────────────────────────────────────────────
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        printf "\n"
        printf "${STYLE_BOLD}extr${STYLE_RESET} — extract any supported archive format\n\n"
        printf "${STYLE_BOLD}${FG_CYAN}Usage:${STYLE_RESET}\n"
        printf "  ${STYLE_BOLD}extr${STYLE_RESET} ${FG_MAGENTA}<archive>${STYLE_RESET} [${FG_YELLOW}<dest_dir>${STYLE_RESET}]\n"
        printf "  ${STYLE_BOLD}extr${STYLE_RESET} ${FG_YELLOW}-h, --help${STYLE_RESET}\n\n"
        printf "${STYLE_BOLD}${FG_CYAN}Supported formats:${STYLE_RESET}\n"
        printf "  tar.bz2  tbz2  tar.gz  tgz  tar.xz  txz  tar  bz2  gz  zip  rar  7z\n\n"
        printf "${STYLE_BOLD}${FG_CYAN}Arguments:${STYLE_RESET}\n"
        printf "  ${FG_MAGENTA}<archive>${STYLE_RESET}    Archive file to extract (required).\n"
        printf "  ${FG_YELLOW}<dest_dir>${STYLE_RESET}   Destination directory (default: current directory).\n\n"
        printf "${STYLE_BOLD}${FG_CYAN}Examples:${STYLE_RESET}\n"
        printf "  extr archive.tar.gz\n"
        printf "  extr archive.zip  ~/extracted\n\n"
        return 0
        ;;
      -*)
        printf "${COLOR_ERROR}Error:${STYLE_RESET} unknown option '%s'.\n" "$1" >&2
        printf "${COLOR_INFO}Hint:${STYLE_RESET}  run 'extr --help' for usage.\n" >&2
        return 1
        ;;
      *)
        if [[ -z "$archive" ]]; then
          archive="$1"
        elif [[ "$dest_dir" == "." ]]; then
          dest_dir="$1"
        else
          printf "${COLOR_ERROR}Error:${STYLE_RESET} too many arguments.\n" >&2
          return 1
        fi
        shift
        ;;
    esac
  done

  # ── validate ───────────────────────────────────────────────────────────────
  if [[ -z "$archive" ]]; then
    printf "${COLOR_INFO}Usage:${STYLE_RESET} extr <archive> [<dest_dir>]\n" >&2
    return 1
  fi
  if [[ ! -f "$archive" ]]; then
    printf "${COLOR_ERROR}Error:${STYLE_RESET} file not found: '%s'.\n" "$archive" >&2
    return 1
  fi
  _archive_ensure_dir "$dest_dir" || return 1

  # ── per-format dependency check then extract ───────────────────────────────
  local result=0

  case "$archive" in
    *.tar.bz2|*.tbz2)
      _archive_check_deps tar bunzip2 || return 1
      tar xjf "$archive" -C "$dest_dir"                                 || result=1 ;;
    *.tar.gz|*.tgz)
      _archive_check_deps tar gzip    || return 1
      tar xzf "$archive" -C "$dest_dir"                                 || result=1 ;;
    *.tar.xz|*.txz)
      _archive_check_deps tar         || return 1
      tar xJf "$archive" -C "$dest_dir"                                 || result=1 ;;
    *.tar)
      _archive_check_deps tar         || return 1
      tar xf  "$archive" -C "$dest_dir"                                 || result=1 ;;
    *.bz2)
      _archive_check_deps bunzip2     || return 1
      bunzip2 -c "$archive" > "${dest_dir}/$(basename "${archive%.bz2}")" || result=1 ;;
    *.gz)
      _archive_check_deps gzip        || return 1
      gunzip  -c "$archive" > "${dest_dir}/$(basename "${archive%.gz}")"  || result=1 ;;
    *.zip)
      _archive_check_deps unzip       || return 1
      unzip -q "$archive" -d "$dest_dir"                                || result=1 ;;
    *.rar)
      _archive_check_deps unrar       || return 1
      unrar x "$archive" "$dest_dir"                                    || result=1 ;;
    *.7z)
      _archive_check_deps 7z          || return 1
      7z x "$archive" -o"$dest_dir" -y                                  || result=1 ;;
    *)
      printf "${COLOR_ERROR}Error:${STYLE_RESET} unsupported format: '%s'.\n" "$archive" >&2
      return 1
      ;;
  esac

  if [[ "$result" -ne 0 ]]; then
    printf "${COLOR_ERROR}Error:${STYLE_RESET} extraction failed.\n" >&2
    return 1
  fi

  printf "${COLOR_SUCCESS}${ICON_EXTRACT} Extracted to:${STYLE_RESET} ${FG_CYAN}%s${STYLE_RESET}\n" "$dest_dir"
}

###############################################################################
# _vault
###############################################################################

# Encrypts or decrypts GPG-encrypted tar archives.
#
# Usage:
#   vault <input> --passphrase <pass> [-z]
#   vault -d | --decode <input.tar[.gz].gpg> --passphrase <pass>
#   vault -h | --help
#
# Options:
#   -d, --decode          Decrypt and extract archive.
#   -z                    Compress with gzip before encrypting.
#   --passphrase <pass>   Passphrase (required).
#   -h, --help            Show this help.
#
# Examples:
#   vault secrets/    --passphrase hunter2          # → secrets.tar.gpg
#   vault secrets/ -z --passphrase hunter2          # → secrets.tar.gz.gpg
#   vault -d secrets.tar.gpg    --passphrase hunter2
#   vault -d secrets.tar.gz.gpg --passphrase hunter2
_vault() {
  local input="" ext_pass="" compress="" decode=0

  # ── help ───────────────────────────────────────────────────────────────────
  _vault_usage() {
    printf "\n"
    printf "${STYLE_BOLD}vault${STYLE_RESET} — GPG-encrypted tar archive tool\n\n"
    printf "${STYLE_BOLD}${FG_CYAN}Usage:${STYLE_RESET}\n"
    printf "  ${STYLE_BOLD}vault${STYLE_RESET} ${FG_MAGENTA}<input>${STYLE_RESET} ${FG_YELLOW}--passphrase <pass>${STYLE_RESET} [-z]\n"
    printf "  ${STYLE_BOLD}vault${STYLE_RESET} ${FG_YELLOW}-d, --decode${STYLE_RESET} ${FG_MAGENTA}<input.tar[.gz].gpg>${STYLE_RESET} ${FG_YELLOW}--passphrase <pass>${STYLE_RESET}\n"
    printf "  ${STYLE_BOLD}vault${STYLE_RESET} ${FG_YELLOW}-h, --help${STYLE_RESET}\n\n"
    printf "${STYLE_BOLD}${FG_CYAN}Options:${STYLE_RESET}\n"
    printf "  ${FG_YELLOW}-d, --decode${STYLE_RESET}          Decrypt and extract archive.\n"
    printf "  ${FG_YELLOW}-z${STYLE_RESET}                    Compress with gzip before encrypting.\n"
    printf "  ${FG_YELLOW}--passphrase <pass>${STYLE_RESET}   Passphrase (required).\n"
    printf "  ${FG_YELLOW}-h, --help${STYLE_RESET}            Show this help.\n\n"
    printf "${STYLE_BOLD}${FG_CYAN}Examples:${STYLE_RESET}\n"
    printf "  vault secrets/    --passphrase hunter2          # → secrets.tar.gpg\n"
    printf "  vault secrets/ -z --passphrase hunter2          # → secrets.tar.gz.gpg\n"
    printf "  vault -d secrets.tar.gpg    --passphrase hunter2\n"
    printf "  vault -d secrets.tar.gz.gpg --passphrase hunter2\n\n"
  }

  # ── parse args ─────────────────────────────────────────────────────────────
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        _vault_usage; return 0 ;;
      -d|--decode)
        decode=1; shift ;;
      -z)
        compress=1; shift ;;
      --passphrase)
        if [[ $# -lt 2 ]]; then
          printf "${COLOR_ERROR}Error:${STYLE_RESET} --passphrase requires a value.\n" >&2
          return 1
        fi
        ext_pass="$2"; shift 2 ;;
      --)
        shift
        if [[ $# -gt 0 ]]; then input="${1%/}"; shift; fi ;;
      -*)
        printf "${COLOR_ERROR}Error:${STYLE_RESET} unknown option '%s'.\n" "$1" >&2
        _vault_usage >&2; return 1 ;;
      *)
        if [[ -n "$input" ]]; then
          printf "${COLOR_ERROR}Error:${STYLE_RESET} unexpected argument '%s'.\n" "$1" >&2
          return 1
        fi
        input="${1%/}"; shift ;;
    esac
  done

  # ── validate common ────────────────────────────────────────────────────────
  if [[ -z "$input" ]]; then
    printf "${COLOR_ERROR}Error:${STYLE_RESET} no input specified.\n" >&2
    _vault_usage >&2; return 1
  fi
  if [[ -z "$ext_pass" ]]; then
    printf "${COLOR_ERROR}Error:${STYLE_RESET} --passphrase is required.\n" >&2
    return 1
  fi
  _archive_check_deps gpg tar || return 1

  # ── decrypt ────────────────────────────────────────────────────────────────
  if [[ "$decode" -eq 1 ]]; then
    if [[ ! -f "$input" ]]; then
      printf "${COLOR_ERROR}Error:${STYLE_RESET} '%s' does not exist.\n" "$input" >&2
      return 1
    fi

    local tar_decomp_flag
    case "$input" in
      *.tar.gz.gpg)  tar_decomp_flag="-xzf" ;;
      *.tar.gpg)     tar_decomp_flag="-xf"  ;;
      *)
        printf "${COLOR_ERROR}Error:${STYLE_RESET} unrecognised extension: '%s'.\n" "$input" >&2
        printf "${COLOR_INFO}Hint:${STYLE_RESET}  expected .tar.gpg or .tar.gz.gpg\n" >&2
        return 1 ;;
    esac

    if ! gpg --batch --passphrase-fd 3 -d "$input" 3<<<"$ext_pass" \
         | tar "$tar_decomp_flag" -; then
      printf "${COLOR_ERROR}Error:${STYLE_RESET} decryption failed.\n" >&2
      return 1
    fi

    printf "${COLOR_SUCCESS}${ICON_DECRYPT} Decrypted:${STYLE_RESET} ${FG_CYAN}%s${STYLE_RESET}\n" "$input"

  # ── encrypt ────────────────────────────────────────────────────────────────
  else
    if [[ ! -e "$input" ]]; then
      printf "${COLOR_ERROR}Error:${STYLE_RESET} '%s' does not exist.\n" "$input" >&2
      return 1
    fi

    local tar_create_flag ext
    if [[ "$compress" -eq 1 ]]; then
      tar_create_flag="-czf"
      ext=".tar.gz.gpg"
    else
      tar_create_flag="-cf"
      ext=".tar.gpg"
    fi

    local output="${input}${ext}"
    if [[ -e "$output" ]]; then
      printf "${COLOR_ERROR}Error:${STYLE_RESET} '%s' already exists.\n" "$output" >&2
      return 1
    fi

    if ! tar "$tar_create_flag" - "$input" \
         | gpg --symmetric \
               --cipher-algo AES256 \
               --s2k-mode 3 \
               --s2k-count 65011712 \
               --batch \
               --passphrase-fd 3 \
               -o "$output" 3<<<"$ext_pass"; then
      printf "${COLOR_ERROR}Error:${STYLE_RESET} encryption failed.\n" >&2
      rm -f "$output"
      return 1
    fi

    printf "${COLOR_SUCCESS}${ICON_ENCRYPT} Encrypted:${STYLE_RESET} ${FG_CYAN}%s${STYLE_RESET}\n" "$output"
  fi
}

###############################################################################
# LAZY LOADER (uncomment to defer sourcing until first use)
###############################################################################
#
# _lazy_load_archive_helpers() {
#   local path="${ARCHIVE_HELPERS_PATH:-$DOTFILES_DIR/lib/archive_helpers.sh}"
#   [[ ! -f "$path" ]] && { printf "${COLOR_ERROR}Error:${STYLE_RESET} archive_helpers.sh not found at %s\n" "$path" >&2; return 1; }
#
#   local loaded=0
#
#   _dispatch_archive_tool() {
#     local cmd="$1"; shift
#     if [[ "$loaded" -eq 0 ]]; then
#       # Undefine stubs so the real aliases take over after sourcing.
#       unset -f bkf tgz extr vault _dispatch_archive_tool 2>/dev/null
#       # shellcheck source=/dev/null
#       source "$path"
#       loaded=1
#     fi
#     case "$cmd" in
#       bkf)   _backup  "$@" ;;
#       tgz)   _pack    "$@" ;;
#       extr)  _extract "$@" ;;
#       vault) _vault   "$@" ;;
#     esac
#   }
#
#   # eval is the correct tool for defining a function with a variable name.
#   local cmd
#   for cmd in bkf tgz extr vault; do
#     # shellcheck disable=SC2116
#     eval "$(printf '%s() { _dispatch_archive_tool %s "$@"; }' "$cmd" "$cmd")"
#   done
# }
# _lazy_load_archive_helpers

###############################################################################
# ALIASES
###############################################################################

alias bkf='_backup'    # backup file or directory
alias tgz='_pack'      # create tar.gz archive
alias extr='_extract'  # extract any supported archive format
alias vault='_vault'   # encrypt / decrypt GPG tar archives

## eof