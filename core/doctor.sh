#!/usr/bin/env bash
# Source-only library (see docs/INTERNALS.md). Idempotent.
#
# Minimal pure-bash fallback for `dotfiles doctor`. When python3 is present,
# bin/dotfiles runs the richer core/py/doctor.py instead (which also subsumes
# the old `status` link table). The two paths share the pass/warn/fail contract
# and the non-zero-on-fail exit behavior.
[[ -n "${__DF_DOCTOR_LOADED:-}" ]] && return 0
readonly __DF_DOCTOR_LOADED=1

: "${DOTFILES:?DOTFILES not set — run via bin/dotfiles}"
source "$DOTFILES/core/utils.sh"    # idempotent (self-guarded)
source "$DOTFILES/core/detect.sh"   # idempotent (self-guarded)

DOCTOR_OK=0
DOCTOR_WARN=0
DOCTOR_FAIL=0

_pass() { DOCTOR_OK=$((DOCTOR_OK + 1));     echo -e "${GREEN}[pass]${RESET}  $*"; }
_warn() { DOCTOR_WARN=$((DOCTOR_WARN + 1)); echo -e "${YELLOW}[warn]${RESET}  $*"; }
_fail() { DOCTOR_FAIL=$((DOCTOR_FAIL + 1)); echo -e "${RED}[fail]${RESET}  $*"; }

# Absorbs the stat difference between macOS (BSD) and Linux (GNU).
file_mode() {
    stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1" 2>/dev/null
}

check_env() {
    if [[ -z "${DOTFILES:-}" ]]; then
        _fail "DOTFILES is not set"
    elif [[ ! -d "$DOTFILES" ]]; then
        _fail "DOTFILES directory missing: $DOTFILES"
    else
        _pass "DOTFILES: $DOTFILES"
    fi

    case ":$PATH:" in
        *":$DOTFILES/bin:"*) _pass "\$DOTFILES/bin is in PATH" ;;
        *) _warn "\$DOTFILES/bin not in PATH (dotfiles/dotf may not be callable)" ;;
    esac

    # Does the dotfiles on PATH point to a different repo? (drift)
    local on_path resolved
    on_path="$(command -v dotfiles 2>/dev/null || true)"
    if [[ -n "$on_path" ]]; then
        resolved="$(cd -P "$(dirname "$on_path")/.." 2>/dev/null && pwd)"
        [[ "$resolved" != "$DOTFILES" ]] && \
            _warn "dotfiles on PATH points to a different repo: $resolved"
    fi
}

check_tools() {
    if command -v git >/dev/null 2>&1; then
        if git -C "$DOTFILES" rev-parse --git-dir >/dev/null 2>&1; then
            if [[ -n "$(git -C "$DOTFILES" status --porcelain)" ]]; then
                _warn "Repo has uncommitted changes"
            else
                _pass "git repo is clean"
            fi
            local counts behind ahead
            if counts="$(git -C "$DOTFILES" rev-list --count --left-right '@{u}...HEAD' 2>/dev/null)"; then
                behind="$(echo "$counts" | awk '{print $1}')"
                ahead="$(echo "$counts" | awk '{print $2}')"
                [[ "${behind:-0}" -gt 0 ]] && _warn "$behind commit(s) behind upstream (dotfiles update)"
                [[ "${ahead:-0}"  -gt 0 ]] && _warn "$ahead commit(s) ahead of upstream (not pushed)"
            fi
        else
            _fail "$DOTFILES is not a git repo"
        fi
    else
        _warn "git missing (update won't work)"
    fi

    if command -v python3 >/dev/null 2>&1; then
        _pass "python3 found"
    else
        _warn "python3 missing (template / os --diff disabled)"
    fi

    case "$(detect_os)" in
        macos)
            command -v brew >/dev/null 2>&1 \
                && _pass "Homebrew found" \
                || _warn "brew missing (os setup won't work)"
            [[ -f "$DOTFILES/config/homebrew/Brewfile" ]] || _warn "Brewfile missing"
            ;;
        linux)
            command -v apt >/dev/null 2>&1 || command -v apt-get >/dev/null 2>&1 \
                || _warn "apt not found"
            ;;
    esac
}

check_symlinks() {
    local manifest="$DOTFILES/.symlinks"
    if [[ ! -f "$manifest" ]]; then
        _fail "manifest missing: $manifest"
        return
    fi

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }"          ]] && continue

        local src target flags mode dirmode
        src=$(echo "$line"    | awk '{print $1}')
        target=$(echo "$line" | awk '{print $3}')
        flags=$(echo "$line"  | awk '{print $4}')
        target="${target/#\~/$HOME}"

        if [[ ! -e "$DOTFILES/$src" ]]; then
            _fail "source missing: $src"
            continue
        fi

        if [[ "$flags" == "[template]" ]]; then
            if [[ ! -e "$target" ]]; then
                _warn "template not rendered: $target"
                continue
            fi
            mode="$(file_mode "$target")"
            [[ "$mode" == "600" ]] || _warn "template mode is not 0600 ($mode): $target"
            if [[ "$(basename "$(dirname "$target")")" == ".ssh" ]]; then
                dirmode="$(file_mode "$(dirname "$target")")"
                [[ "$dirmode" == "700" ]] || _warn "~/.ssh mode is not 0700 ($dirmode)"
            fi
            _pass "template: $target"
            continue
        fi

        if [[ -L "$target" ]]; then
            if [[ "$(readlink "$target")" == "$DOTFILES/$src" ]]; then
                _pass "link: $target"
            else
                _fail "wrong target: $target → $(readlink "$target")"
            fi
        elif [[ -e "$target" ]]; then
            _warn "file exists but is not a link: $target"
        else
            _fail "link missing: $target"
        fi
    done < "$manifest"
}

check_misc() {
    [[ -x "$DOTFILES/bin/dotfiles" ]] || _warn "bin/dotfiles is not executable"
    [[ -x "$DOTFILES/bin/dotf"     ]] || _warn "bin/dotf is not executable"
    [[ -f "$DOTFILES/vars/local.env" ]] || _warn "vars/local.env missing (template variables may be incomplete)"
}

run_doctor() {
    log_info "dotfiles doctor — OS: $(detect_os) | Shell: $(detect_shell)"
    echo
    # Each check is called fault-tolerantly: if a check's last command is a
    # `[[ ... ]] && _warn` that evaluates false, the function returns non-zero;
    # since bin/dotfiles runs under `set -e`, a bare call would kill the whole
    # process. We guard with `|| true` so that ONLY DOCTOR_FAIL decides the result.
    check_env      || true
    check_tools    || true
    check_symlinks || true
    check_misc     || true
    echo
    echo -e "${GREEN}$DOCTOR_OK ok${RESET}, ${YELLOW}$DOCTOR_WARN warn${RESET}, ${RED}$DOCTOR_FAIL fail${RESET}"
    [[ "$DOCTOR_FAIL" -gt 0 ]] && return 1
    return 0
}
