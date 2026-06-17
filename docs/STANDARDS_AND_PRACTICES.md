# Shell Scripting Standards and Best Practices

Three file roles exist in this repo. Pick the right one before writing anything.
See [INTERNALS.md](INTERNALS.md) for the canonical patterns.

| Role | Where | Shebang | `set -e` | `DOTFILES` guard |
| --- | --- | --- | --- | --- |
| **Execute-only script** | `os/macos/*.sh`, `bin/dotfiles` | `#!/usr/bin/env bash` | yes | entry point — self-locates |
| **Source-only library** | `core/*.sh`, `shell/common/*.sh` | none | inherited | `: "${DOTFILES:?}"` |
| **Interactive-only library** | `shell/common/tool_loader.sh`, `shell/common/nvm.sh` | none | inherited | `: "${DOTFILES:?}"` |

---

## 1. Source-only library

No shebang. Opens with idempotency guard and `DOTFILES` assertion.
Logging via `core/utils.sh` (`log_info/ok/warn/error`). Never calls `exit`.

```bash
# shellcheck shell=bash
# One-line description. Sourced by <caller>. Idempotent.
[[ -n "${__DF_NAME_LOADED:-}" ]] && return 0
readonly __DF_NAME_LOADED=1

: "${DOTFILES:?DOTFILES not set — source exports.sh first}"
source "$DOTFILES/core/utils.sh"

# implementation
```

> Interactive-only libraries follow the same pattern but are only sourced from
> `.zshrc` / `.bashrc` — never from `exports.sh` or non-interactive paths.
> See [INTERNALS.md](INTERNALS.md) for the tool_loader pattern.

---

## 2. Execute-only script (`os/macos/*.sh` style)

Has a shebang, `set -euo pipefail`, an execute-guard (refuse to be sourced),
and a `trap`-based cleanup. Self-locates `$DOTFILES` via `LIB_DIR`.

```bash
#!/usr/bin/env bash
# $DOTFILES/os/macos/script_name.sh
#
# Description:
#   One-sentence summary.
#
# Usage:
#   script_name.sh [--dry-run] [--help]
#
# Options:
#   --dry-run    Print actions without executing them
#   --help, -h   Display usage and exit
#
# Dependencies:
#   - List required external commands (e.g. git, curl, jq)
#
# Return Codes:
#   0    Success
#   20   Authentication failed (sudo)
#   64   Invalid usage
#   127  Command not found

# must be executed directly, not sourced
[[ "${BASH_SOURCE[0]}" != "$0" ]] && { printf "[ERROR] Do not source this script\n" >&2; exit 64; }

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

LIB_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$LIB_DIR/../lib.sh"   # shared os/lib.sh: logging, dry_run_exec, confirm, sudo keep-alive

readonly SCRIPT_NAME="$(basename "$0")"
# EXIT_SUCCESS / EXIT_AUTH_FAILED / EXIT_INVALID_USAGE / EXIT_CMD_NOT_FOUND
# (0 / 20 / 64 / 127) come from os/lib.sh — do not redefine them here.

dry_run=false

_TEMP_DIR="$(mktemp -d "/tmp/${SCRIPT_NAME}.XXXXXX")"
cleanup() { rm -rf "$_TEMP_DIR"; }
trap cleanup EXIT INT TERM

show_help() {
  cat <<EOF
Usage: $SCRIPT_NAME [--dry-run] [--help]

Description here.

Options:
  --dry-run    Print actions without executing them
  --help, -h   Display this help message and exit
EOF
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --dry-run)   dry_run=true ;;
      --help|-h)   show_help; exit $EXIT_SUCCESS ;;
      *)           log_error "Unknown option: $1"; show_help; return $EXIT_INVALID_USAGE ;;
    esac
    shift
  done
}

main() {
  parse_args "$@" || return $?
  log_info "Starting $SCRIPT_NAME"
  # implementation
  log_success "$SCRIPT_NAME completed"
}

main "$@"
exit $?
```

---

## 3. Naming & style

- **Functions:** `snake_case`; `cmd_<name>` for CLI handlers; `_leading_underscore` for internals.
- **Variables:** `UPPER_SNAKE` for env/globals; `local lower` inside functions.
- **Logging:** always via `log_info/ok/warn/error` (from `core/utils.sh`); never raw `echo`.
- **Comments:** English only. Write the *why*, not the *what*. See [§4](#4-comment--header-conventions).
- **Guards:** source-only libraries always open with the `__DF_<NAME>_LOADED` guard. Idempotency is non-negotiable.
- **`return` vs `exit`:** sourced libraries use `return` for early-out; execute-only scripts use `exit`.
- **Syntax check before merging:** `bash -n <file>` / `zsh -n <file>` / `shellcheck <file>`, then `dotfiles doctor`.

---

## 4. Comment & header conventions

Comments fall into four kinds. The weight of a comment scales with the file's
role — a sourced helper gets one line; an executable entry point gets a full
header. Pick the kind, then follow its rule.

### 4.1 File header (top-of-file block)

Drive the header off the file role (§ table above), not personal taste.

| Role | Header |
| --- | --- |
| **Source-only library** | No banner. 1–2 comment lines (description + how it's sourced), then the guard. The minimal form from §1 — see `core/utils.sh`, `core/doctor.sh`. |
| **Interactive library** with required env/deps | Banner allowed when it documents `ENVIRONMENT` / `DEPENDENCIES` the caller must satisfy — see `shell/common/functions.sh`. Keep it; don't add one just for decoration. |
| **Execute-only script** | Full banner + usage block (§4.3). `os/*/*.sh`, `install.sh`, `bin/dotfiles`. |
| **Python module** | Module docstring under the shebang — every `core/py/*.py` and `tools/*` gets one, no exceptions. PEP 257 form: a one-line summary on the opening `"""` line ending in a period; an executable tool may then add a blank line and a `Usage`/`Options` body. Never open with a bare `"""` followed by the summary on the next line. |

**One banner style only.** Use the 78-column equals rule. Never `#####`, and
never mix two banner styles in the same file:

```bash
# =============================================================================
# name.sh — one-line summary (em-dash separator)
#
# ... body ...
# =============================================================================
```

### 4.2 Block comments (a paragraph above a code section)

Reserve these for a section that genuinely needs context (a tricky algorithm, a
platform quirk, a non-obvious ordering constraint). Explain the *why*. Do not
narrate sequential steps the code already shows. If a block is only restating
the next three lines, delete it.

Section dividers inside a file, when used, follow the header style:
`# --------------------------------------------------------- short label`.
Don't introduce a third divider character.

### 4.3 Usage block (executable scripts & CLI tools)

One template, fixed heading order. Skip a heading that doesn't apply; never
reorder the ones that do:

```text
Description → Usage → Sections → Options → Dependencies → Environment → Return Codes
```

`os/*/*.sh` and `tools/*` must converge on this skeleton. Notes:

- **Sections** is the slot for domain-specific selectors; a script that selects
  *what to act on* rather than *areas* may title it **Targets** instead (e.g.
  `os/macos/cleanup.sh`). Domain selectors come before the generic **Options**.
- **Return Codes** list the codes the script can actually return. Execute-only
  scripts inherit them from `os/lib.sh`: `0` success, `20` auth failed, `64`
  invalid usage, `127` command not found.
- The runtime `--help` output (`show_help`) should mirror the header — same
  options, same wording.

### 4.4 Inline comments (trailing or above a single line)

- Write the *why*, not the *what*. Bad: `# loop over files`. Good: `# BSD stat
  has no -c; fall back per platform`.
- Trailing inline comments are separated by two spaces and may be aligned within
  a block: `source "$DOTFILES/core/utils.sh"   # idempotent (self-guarded)`.
- One short line. If it needs a paragraph, it's a block comment (§4.2).

### 4.5 Cross-cutting rules

- **English only**, across every comment kind.
- **Em-dash `—`** is the separator in `name — description` headers (not `-`).
- **Shebangs:** `#!/usr/bin/env bash` for bash, `#!/usr/bin/env python3` for
  Python. No `#!/bin/bash`.
- A comment that documents structure already covered by [INTERNALS.md](INTERNALS.md)
  should link to it rather than restate it.
