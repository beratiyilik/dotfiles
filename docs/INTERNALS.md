# Internals — Lifecycle, Sourcing & Path Resolution

The complete technical reference for how this dotfiles system works: every
file's role, how the system boots, how files find each other, and what patterns
to follow when adding new scripts.

---

## Mental model

There are **two independent runtime lifelines**. Understanding this split is
the key to reading the rest of this document.

**Management CLI** (`bin/dotfiles`) — only runs when you explicitly call
`dotfiles <command>`. It sources `core/*.sh` into itself and launches
`core/py/*.py` and `os/macos/*.sh` as subprocesses.

**Shell runtime** — runs on every terminal open, driven by the 🔗 rc files
symlinked into `$HOME` during the `link` stage. Each rc file then sources the
`shell/common/*` libraries. The CLI is never involved here.

**Bridge:** Stage 3 (`link`) is the only point where these two lifelines
connect — it is where every 🔗 file gets wired into `$HOME`.

---

## Guiding principle

> **Derive the root at the boundary; trust it everywhere inside.**

The rc files are symlinked into `$HOME`, so when they start "cold" `DOTFILES`
is unset and `$0` / `BASH_SOURCE` point at the symlink. Entry-point files must
therefore locate the repo root themselves. Everything they reach afterwards —
`core/` and `shell/common/` libraries — is only ever loaded *after* the root is
known and exported, so it must **not** re-derive it.

---

## File invocation types

| Type | Meaning |
|------|---------|
| 🔗 LINK | Symlinked into `$HOME` via `.symlinks` (content file) |
| ▶️ EXEC | Run as a program (on PATH or via `bash X`) |
| ⤵️ EXEC-SUB | Launched as a subprocess by `bin/dotfiles` (`bash X` / `"$PYTHON" X`) |
| 📥 SRC-CLI | Sourced inside `bin/dotfiles` (management core) |
| 📥 SRC-SH | Sourced at shell startup (`.zshrc` / `.bashrc` / `.zshenv`) |
| 📄 DATA | Read as data / manifest (not symlinked, not executed) |
| 📕 DOC | Documentation only, no runtime role |

---

## Lifecycle stages

### Stage 0 — Bootstrap (one-time)

```
install.sh  (▶️ EXEC: ./install.sh  or  curl | bash)
   ├─ Scenario (a) local clone: DOTFILES = directory install.sh lives in
   ├─ Scenario (b) curl | bash: git clone → $DOTFILES (default: $HOME/dotfiles)
   ├─ chmod +x bin/dotfiles ; prepend bin/ to PATH
   ├─ vars/local.env absent → cp vars/local.env.sample vars/local.env
   └─ exec → dotfiles init
```

### Stage 1 — Every CLI invocation (shared core)

```
bin/dotfiles  (▶️ EXEC: on PATH; bin/dotf is a repo-internal symlink to dotfiles)
   ├─ DOTFILES self-locate (resolves symlink chain, walks up to repo root) + export
   ├─ 📥 core/detect.sh   → detect_os / detect_shell / detect_python
   ├─ 📥 core/utils.sh    → log_*, confirm, colors, clone_if_missing  (sources core/guards.sh)
   ├─ 📥 core/guards.sh   → is_macos / is_linux / is_arm64 / has_cmd  (predicate standard; also via os/lib.sh)
   └─ PYTHON="$(detect_python)"; export PYTHON        ← detected once, reused by all subprocesses
      OS / SHELL_NAME derived → dispatch to subcommand (case)
```

`PYTHON`, `OS`, and `DOTFILES` are determined here exactly once. Sourced
libraries and Python subprocesses must reuse them — never re-detect.

### Stage 2 — `init` (installation orchestration)

```
dotfiles init
   ├─ 📥 hooks/pre-init.sh        (if present; runs under set -e; before link)
   ├─ → link                      (Stage 3)
   ├─ OS setup:
   │     macos → ⤵️ bash os/macos/defaults.sh --all --force   (|| true: fault-tolerant)
   │     linux → 📥 os/linux/apt.sh   (reads 📄 os/linux/packages.txt)
   └─ 📥 hooks/post-init.sh       (if present; after OS setup)
                                   → clones oh-my-zsh + p10k + 3 zsh plugins (idempotent, KEEP_ZSHRC=yes)
```

### Stage 3 — `link` (manifest executor — symlinks created here) ⭐

```
dotfiles link
   └─ 📥 core/symlinks.sh : link_all()
         ├─ 📄 .symlinks read line by line (comments / blank lines skipped)
         ├─ 📥 core/backup.sh : backup_file()    (backs up real file at target if present)
         ├─ plain line   → mkdir -p $(dirname) ; ln -sf
         │                 → every 🔗 LINK file is wired into $HOME
         └─ [template] line → ⤵️ "$PYTHON" core/py/template.py  (output chmod 0600)
              └─ no [template] lines in .symlinks currently — path is supported but dormant
```

**Bridge rule:** every 🔗 file is wired into `$HOME` here and only here.
Everything else is sourced, exec'd as a subprocess, or called from PATH — never
symlinked.

### Stage 4 — On-demand commands

```
dotfiles os       → macos: brew bundle --file=📄 config/homebrew/Brewfile
                    linux: 📥 os/linux/apt.sh
dotfiles os --diff→ ⤵️ "$PYTHON" core/py/packages.py "$OS"
                         reads Brewfile via subprocess; does NOT import manifest.py
dotfiles backup   → 📥 core/backup.sh (reads 📄 .symlinks, backs up each target)
dotfiles doctor   → python? ⤵️ "$PYTHON" core/py/doctor.py  (🐍 from manifest import parse)
                    else    📥 core/doctor.sh run_doctor      (minimal bash fallback)
                    .symlinks / Brewfile / local.env health check; per-target link state
dotfiles update   → git pull --ff-only + → link
```

### Stage 5 — Shell startup (runtime of the linked configs)

> Key asymmetry: **bash has no `.zshenv` equivalent.** So `exports.sh` is
> sourced from `.zshenv` in zsh and from `.bashrc` in bash.

```
zsh:                                          bash:
~/.zshenv 🔗  (every invocation: login/script) ~/.bash_profile 🔗  (login)
  └─ 📥 shell/common/exports.sh                  └─ source ~/.bashrc 🔗
       └─ 📄 vars/common.env + local.env (set -a)
       └─ defines feature flags                ~/.bashrc 🔗  (interactive core)
                                                 ├─ DOTFILES self-locate + homebrew shellenv
~/.zprofile 🔗  (login: path_prepend bin+tools)  ├─ 📥 shell/common/exports.sh
                                                 ├─ 📥 shell/common/functions.sh
~/.zshrc 🔗  (interactive)                        ├─ 📥 shell/common/aliases.sh
  ├─ p10k instant-prompt (top, for speed)         ├─ 📥 shell/common/diag.sh
  ├─ homebrew shellenv + PATH + pyenv             ├─ 📥 shell/common/tool_loader.sh  ← flag dispatcher
  ├─ oh-my-zsh + plugins + ~/.p10k.zsh 🔗          ├─ completion (bash-completion / ssh / docker)
  ├─ 📥 config/fzf/.fzf.sh + zoxide               ├─ direnv / bat / pyenv / fzf / zoxide
  ├─ 📥 shell/common/functions.sh                  ├─ path_prepend bin + tools
  ├─ 📥 shell/common/aliases.sh                    └─ 📥 ~/.bashify/bashify.bash  (prompt, external)
  ├─ 📥 shell/common/diag.sh
  └─ 📥 shell/common/tool_loader.sh  ← flag dispatcher
```

#### Stage 5b — `tool_loader.sh`: conditional lib dispatcher

`shell/common/tool_loader.sh` is sourced only from interactive startup files
(`.zshrc`, `.bashrc`) — **never from `exports.sh`**. Sourcing heavy tools
inside `exports.sh` would run them in every zsh invocation, including
subshells and scripts, causing unnecessary slowdown.

```
shell/common/tool_loader.sh
   │  flags defined in exports.sh; overridable per-machine in vars/local.env:
   ├─ DOTFILES_ENABLE_NVM=true             → 📥 shell/common/nvm.sh
   │                                            lazy-loads nvm: aliases node/npm/yarn/npx/pnpm
   │                                            that source the real nvm.sh on first use
   ├─ DOTFILES_ENABLE_GIT_HELPERS=true     → 📥 shell/common/git.sh
   ├─ DOTFILES_ENABLE_AWS_HELPERS=false    → (skipped)
   └─ DOTFILES_ENABLE_ESP_IDF_HELPERS=false→ (skipped)
```

Enable a helper per-machine in `vars/local.env`:

```sh
DOTFILES_ENABLE_AWS_HELPERS=true
```

### Stage 6 — OS maintenance (on-demand, all EXEC-SUB)

```
dotfiles upgrade  → ⤵️ bash os/$OS/update.sh   "$@"
dotfiles cleanup  → ⤵️ bash os/$OS/cleanup.sh  "$@"
dotfiles snapshot → ⤵️ bash os/$OS/snapshot.sh "$@"   (includes Brewfile dump)
dotfiles defaults → ⤵️ bash os/$OS/defaults.sh "$@"
        each one → 📥 os/lib.sh  (self-located one level up via ${BASH_SOURCE[0]})
        cmd_os_script: warns + returns non-zero when os/$OS/<script>.sh is absent
        (os/macos/* are implemented; os/linux/* are placeholder stubs — echo only)
```

---

## Source dependency graph

The lifecycle stages above are *time-ordered* (when each file loads). This is the
complementary **static** view — which library `source`s which (`→` = "sources"),
and why the predicate standard has to be wired in two places.

### Core libraries — layered, leaves first

```
core/detect.sh    ·  leaf (sources nothing)   — canonical OS map (detect_os)
core/paths.sh     ·  leaf (sources nothing)   — backup roots / timestamps
core/guards.sh    →  detect.sh                — is_macos / is_linux / is_arm64 / has_cmd
core/utils.sh     →  guards.sh → detect.sh    — log_* / confirm / clone_if_missing
core/backup.sh    →  utils.sh, paths.sh
core/symlinks.sh  →  utils.sh, backup.sh
core/doctor.sh    →  utils.sh, detect.sh
os/lib.sh         →  ../core/guards.sh → detect.sh   — os maintenance toolkit
```

### Two roots (no single library spans both — see *Mental model*)

- **CLI** — `bin/dotfiles` sources `detect.sh` + `utils.sh` at startup (so `guards.sh`
  loads transitively); per command it adds `symlinks.sh`, `backup.sh`, `doctor.sh`,
  `os/linux/apt.sh`, and the hooks. For call *order*, see Stages 1–4.
- **Standalone os scripts** — each `os/{macos,linux}/*.sh` runs as its own `bash`
  process (Stage 6) and self-sources `../lib.sh` (`→ guards.sh → detect.sh`);
  `snapshot.sh` additionally sources `core/paths.sh`.

### Reverse view — who sources each library

| Library | Sourced directly by | Reaches (transitively) |
| --- | --- | --- |
| `core/detect.sh` | `guards.sh`, `doctor.sh`, `bin/dotfiles` | everything (via guards) |
| `core/guards.sh` | **`core/utils.sh`** + **`os/lib.sh`** | the whole repo — exactly two parents |
| `core/utils.sh` | `bin/dotfiles`, `symlinks.sh`, `backup.sh`, `doctor.sh`, `os/linux/apt.sh` | hooks (inherited) |
| `core/paths.sh` | `core/backup.sh`, `os/macos/snapshot.sh` | — |
| `os/lib.sh` | every `os/macos/*` + `os/linux/*` maintenance script | — |

### Two invariants

1. **`guards.sh` enters through exactly two doors** — `utils.sh` (→ the entire CLI
   runtime) and `os/lib.sh` (→ every maintenance script). No single library is sourced
   by both roots, so the predicate standard is deliberately wired in both.
2. **Hooks source nothing.** `hooks/pre-init.sh` / `post-init.sh` inherit `log_*`,
   `is_macos`, `has_cmd`, and `clone_if_missing` from the `utils.sh` + `guards.sh`
   that `bin/dotfiles` already loaded — they work only when sourced by `dotfiles init`,
   never standalone.

---

## Complete file table

| File | Type | How / by whom | Stage |
|------|------|---------------|-------|
| `install.sh` | ▶️ EXEC | manually / `curl \| bash` | 0 |
| `bin/dotfiles` | ▶️ EXEC | PATH (every command) | 1 |
| `bin/dotf` | repo-internal symlink → `dotfiles` | on PATH; not linked to `$HOME` | 1 |
| `core/detect.sh` | 📥 SRC-CLI | `bin/dotfiles` | 1 |
| `core/utils.sh` | 📥 SRC-CLI | `bin/dotfiles` + all core libs | 1 |
| `core/guards.sh` | 📥 SRC-CLI | `core/utils.sh` + `os/lib.sh` (predicate standard: `is_*` / `has_cmd`) | 1 |
| `core/paths.sh` | 📥 SRC-CLI | `core/backup.sh` + `os/macos/snapshot.sh` | 3, 4, 6 |
| `core/symlinks.sh` | 📥 SRC-CLI | `bin/dotfiles` | 3 |
| `core/backup.sh` | 📥 SRC-CLI | `symlinks.sh` + `backup` command | 3, 4 |
| `core/doctor.sh` | 📥 SRC-CLI | `bin/dotfiles` (doctor; bash fallback when no python3) | 4 |
| `core/py/manifest.py` | 🐍 IMPORT | imported by `doctor.py` only | 4 |
| `core/py/doctor.py` | ⤵️ EXEC-SUB | `"$PYTHON"` (doctor, when python3 present) | 4 |
| `core/py/packages.py` | ⤵️ EXEC-SUB | `"$PYTHON"` (os --diff); does NOT import manifest | 4 |
| `core/py/template.py` | ⤵️ EXEC-SUB | `symlinks.sh` ([template]); no [template] lines in .symlinks currently | 3 (dormant) |
| `hooks/pre-init.sh` | 📥 SRC-CLI | `init` (before link, conditional) | 2 |
| `hooks/post-init.sh` | 📥 SRC-CLI | `init` (after OS setup, conditional) | 2 |
| `os/linux/apt.sh` | 📥 SRC-CLI | `bin/dotfiles` (linux) | 2, 4 |
| `os/linux/packages.txt` | 📄 DATA | read by `apt.sh` | 2, 4 |
| `os/linux/{update,cleanup,snapshot,defaults}.sh` | ⤵️ EXEC-SUB | `bash … "$@"` (upgrade/cleanup/snapshot/defaults on linux) — placeholder stubs, not implemented yet | 6 |
| `os/macos/defaults.sh` | ⤵️ EXEC-SUB | `bash … "$@"` (init; `defaults` command) | 2, 6 |
| `os/macos/defaults.conf` | 📄 DATA | read by `defaults.sh` (committed base) | 2, 6 |
| `os/macos/defaults.local.conf` | 📄 DATA | read by `defaults.sh` if present (gitignored, machine overrides) | 2, 6 |
| `os/macos/update.sh` | ⤵️ EXEC-SUB | `bash … "$@"` (upgrade) | 6 |
| `os/macos/cleanup.sh` | ⤵️ EXEC-SUB | `bash … "$@"` (cleanup) | 6 |
| `os/macos/snapshot.sh` | ⤵️ EXEC-SUB | `bash … "$@"` (snapshot) | 6 |
| `os/lib.sh` | 📥 (bash-internal) | the per-OS maintenance scripts (e.g. `os/macos/*.sh`) via `${BASH_SOURCE[0]}/../lib.sh` | 6 |
| `shell/zsh/.zshenv` | 🔗 LINK | zsh every invocation; sources `exports.sh` | 3→5 |
| `shell/zsh/.zprofile` | 🔗 LINK | login zsh; PATH (bin + tools) | 3→5 |
| `shell/zsh/.zshrc` | 🔗 LINK | interactive zsh | 3→5 |
| `shell/bash/.bash_profile` | 🔗 LINK | login bash; sources `.bashrc` | 3→5 |
| `shell/bash/.bashrc` | 🔗 LINK | interactive bash core | 3→5 |
| `shell/common/exports.sh` | 📥 SRC-SH | `.zshenv` + `.bashrc` | 5 |
| `shell/common/functions.sh` | 📥 SRC-SH | `.zshrc` + `.bashrc` | 5 |
| `shell/common/aliases.sh` | 📥 SRC-SH | `.zshrc` + `.bashrc` | 5 |
| `shell/common/diag.sh` | 📥 SRC-SH | `.zshrc` + `.bashrc` | 5 |
| `shell/common/tool_loader.sh` | 📥 SRC-SH | `.zshrc` + `.bashrc` (interactive only) | 5 |
| `shell/common/nvm.sh` | 📥 SRC-SH (conditional) | `tool_loader.sh` when `ENABLE_NVM=true` | 5 |
| `shell/common/git.sh` | 📥 SRC-SH (conditional) | `tool_loader.sh` when `ENABLE_GIT_HELPERS=true` | 5 |
| `shell/common/aws.sh` | 📥 SRC-SH (conditional) | `tool_loader.sh` when `ENABLE_AWS_HELPERS=true` | 5 |
| `shell/common/esp.sh` | 📥 SRC-SH (conditional) | `tool_loader.sh` when `ENABLE_ESP_IDF_HELPERS=true` | 5 |
| `~/.bashify/bashify.bash` (external repo) | 📥 SRC-SH | `.bashrc` directly (conditional prompt); installed by `hooks/post-init.sh` | 5 |
| `config/fzf/.fzf.sh` | 📥 SRC-SH | `.zshrc` + `.bashrc` | 5 |
| `tools/ai_rename`, `tools/archive`, `tools/git_ai` | ▶️ EXEC | PATH (`tools/`); interpreter via shebang | 5+ |
| `vars/common.env` | 📄 DATA | `exports.sh` (set -a) + `template.py`; feature flag defaults | 3, 5 |
| `vars/local.env` | 📄 DATA | same (gitignored; flag overrides, credentials) | 3, 5 |
| `vars/local.env.sample` | 📄 DATA | `install.sh` copies to `local.env` on first run | 0 |
| `config/git/`, `config/vim/`, `config/nano/`, `config/tmux/`, `config/readline/`, `config/editorconfig/`, `config/aws/`, `config/ssh/`, `config/1Password/`, `config/p10k/` | 🔗 LINK | `.symlinks` → `$HOME` | 3 |
| `config/homebrew/Brewfile` | 📄 DATA | `brew bundle --file=` + `packages.py` | 4 |
| `.symlinks` | 📄 DATA | `symlinks.sh`, `doctor.py` (via manifest), `doctor.sh`, `backup` | 3, 4 |
| `docs/*.md`, `README.md`, `LICENSE` | 📕 DOC | — | — |

### Inactive / unlisted files

| File | Status |
|------|--------|
| `config/starship/starship.toml` | Commented in `.symlinks` — in repo, not linked |
| `shell/zsh/.zlogout`, `shell/bash/.bash_logout`, `shell/zsh/.zlogin`, `shell/bash/.profile` | Commented in `.symlinks` — passive |
| `shell/zsh/.zsh_history_seed` | Manual: `cat … >> ~/.zsh_history && fc -R` |
| `config/tmux/.tmux.localai.sh` | Manual / `tmlocalai` alias; `.tmux.conf` does not auto-invoke it |
| `core/py/template.py` | Code is live; no `[template]` entries in `.symlinks` currently → dormant |

---

## Canonical patterns

### 1. Deriving `DOTFILES` (entry points only)

**zsh** — `:A` resolves symlinks; no manual `readlink` loop needed. `.zshenv`
is the canonical home (sourced on every invocation); `.zshrc` keeps a *guarded*
fallback for the rare case it runs without `.zshenv`.

```zsh
if [[ -z "${DOTFILES:-}" ]]; then
  DOTFILES="${${(%):-%x}:A:h:h:h}"   # :h per directory level down from root
fi
export DOTFILES
```

**bash** — no `:A` equivalent; walk the symlink chain explicitly. Canonical in
`bin/dotfiles`; `shell/bash/.bashrc` mirrors it with one extra `..` (it sits
two levels below the root instead of one).

```bash
if [[ -z "${DOTFILES:-}" ]]; then
    __self="${BASH_SOURCE[0]}"
    while [[ -L "$__self" ]]; do
        __dir="$(cd -P "$(dirname "$__self")" && pwd)"
        __self="$(readlink "$__self")"
        [[ "$__self" != /* ]] && __self="$__dir/$__self"
    done
    DOTFILES="$(cd -P "$(dirname "$__self")/.." && pwd)"   # adjust depth as needed
    unset __self __dir
fi
export DOTFILES
```

> `install.sh` uses a simpler single-level derivation: it is always run as a
> real file (local clone or `curl | bash`), never through a symlink.

### 2. Source-only library header

Every sourced library opens the same way: fail loud if the root is missing,
then guard against double-sourcing.

```bash
#!/usr/bin/env bash
# Source-only library (see docs/INTERNALS.md). Idempotent.
[[ -n "${__DF_<NAME>_LOADED:-}" ]] && return 0
readonly __DF_<NAME>_LOADED=1

: "${DOTFILES:?DOTFILES not set — run via bin/dotfiles}"
source "$DOTFILES/core/utils.sh"   # idempotent (self-guarded)
```

- `: "${DOTFILES:?…}"` replaces the old `${DOTFILES:-$HOME/dotfiles}` magic
  fallback, which silently assumed a path and masked bugs.
- The `__DF_<NAME>_LOADED` guard means every library can be sourced
  unconditionally (no `[[ -z … ]] &&` dance required at call sites).

### 3. Loading shared libraries

- **Inside the CLI** (`bin/` → `core/`): `source "$DOTFILES/<path>"`. Root is
  guaranteed.
- **Shell startup** (`.zshrc`, `.bashrc`): also `source "$DOTFILES/shell/common/<lib>"` —
  direct paths in both shells (do not route zsh through `$SHELL_*_PATH` while
  bash uses a literal path; keep them symmetric).
- **OS maintenance execute-only scripts** (`os/<os>/*.sh`): resolve the script's
  own directory and source the shared `os/lib.sh` one level up (`../lib.sh`) —
  self-relative, independent of `DOTFILES`.

### 4. Execute-only guard (OS maintenance scripts)

```bash
# must be executed directly, not sourced
[[ "${BASH_SOURCE[0]}" != "$0" ]] && { printf "[ERROR] Do not source this script\n" >&2; exit 64; }
LIB_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/../lib.sh"   # shared os/lib.sh, one level up
```

### 5. Invoking other interpreters

- Run macOS tools as a subprocess: `bash "$DOTFILES/os/macos/<script>.sh" "$@"`.
- Python is detected **once** in `bin/dotfiles` (`PYTHON="$(detect_python)"; export PYTHON`).
  Sourced libs read `${PYTHON:-}`; subprocesses are called as
  `"$PYTHON" "$DOTFILES/core/py/<x>.py"` with `PYTHONPATH="$DOTFILES/core/py"`.
  Never re-detect Python in libraries.

### 6. The `dotf` alias

`bin/dotf` is a relative **symlink** to `dotfiles` (not a shim script), so
there is no second copy of the path-resolution logic to keep in sync.
`bin/dotfiles` self-locates correctly however it is invoked.

---

## Local overrides (`vars/local.env`)

`vars/local.env` is the **single** mechanism for machine-specific configuration.
It is gitignored, lives inside the repo, and is created automatically on first
run (`install.sh` copies `vars/local.env.sample` → `vars/local.env`). On an
existing clone copy it yourself:

```sh
cp vars/local.env.sample vars/local.env
```

| What to put here | Example |
|---|---|
| Credentials & API keys | `CLAUDE_API_KEY=sk-ant-...` |
| Feature flag overrides | `DOTFILES_ENABLE_AWS_HELPERS=true` |
| Tool endpoint / model overrides | `AI_API_URL=http://192.168.1.100:11434/api/generate` |
| SSH identity override | `SSH_IDENTITY=~/.ssh/id_ed25519_work` |

**Rules:**

- `KEY=value` only — no `export`, no `$(...)`, no shell expansion
- Loaded after `vars/common.env`, so any key here overrides the common default
- Also read by `core/py/template.py` for `{{KEY}}` substitution in `.tmpl` files
- Never add to `.symlinks` — it is local by design, not deployed from the repo
- `vars/local.env.sample` is committed and serves as the reference for all available keys

There is no `~/.dotfiles.local` mechanism. One file, one place.

---

## Checklist when adding a script

- [ ] Pick the role (entry point / source-only / execute-only / interactive-only) and follow its pattern.
- [ ] Source-only? Add the `: "${DOTFILES:?…}"` guard and a `__DF_<NAME>_LOADED` idempotency guard.
- [ ] Entry point? Use the canonical `DOTFILES` derivation snippet for your shell.
- [ ] Interactive-only (heavy / UI code)? Put it behind a `DOTFILES_ENABLE_*` flag in `tool_loader.sh`, not in `exports.sh`.
- [ ] Need Python? Read `${PYTHON:-}` / pass `"$PYTHON"`; set `PYTHONPATH`; never re-detect.
- [ ] New symlink? Add it to `.symlinks` and update `vars/local.env.sample` if it needs any template variables.
- [ ] Verify: `bash -n` / `zsh -n` / `python3 -m py_compile`, then `dotfiles doctor`.
