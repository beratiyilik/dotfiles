# dotfiles

A small, dependency-light **dotfiles manager** that installs and maintains your shell
and tool configuration through a single declarative manifest and one CLI (`dotfiles`,
aliased `dotf`).

---

## 1. Project Overview

### Purpose

This project keeps your personal development environment — shell startup files,
Git, Vim, tmux, and SSH configuration — under version control and reproducible on
any new machine with a single command. You declare *which file links where* once,
and the CLI does the rest: symlinking, templating secrets, backing up what was
already there, and running OS-specific setup.

### Core value proposition

- **One source of truth.** All configuration lives in this repo; your `$HOME` only
  holds symlinks back to it. Edit once, and every linked location updates instantly.
- **Declarative & idempotent.** A single `.symlinks` manifest describes the desired
  state. Re-running `dotfiles link` converges to that state without creating
  duplicates or clobbering data — existing real files are backed up first.
- **Safe templating.** Files containing secrets (e.g. SSH config) are rendered from
  templates with strict permissions (`0600`, and `0700` for `~/.ssh`).
- **Portable & relocatable.** Pure Bash + Python standard library. No runtime
  dependencies to install. The repo can live anywhere — it self-locates.
- **Self-diagnosing.** `dotfiles doctor` audits environment, symlinks, permissions,
  and tooling, returning a non-zero exit code on failure (CI/script friendly).

### Problems it solves

- "I set up my laptop perfectly but can't reproduce it on a new machine."
- "My `.zshrc` on machine A drifted from machine B."
- "I accidentally overwrote a config and lost the original."
- "I want machine-specific secrets (keys, hosts) without committing them."

### Target audience & personas

| Persona | Need it serves |
|---|---|
| **Individual developer** (primary) | Reproducible personal environment across macOS/Linux machines. |
| **New-machine bootstrapper** | One-line `install.sh` to go from bare OS to configured shell. |
| **AI coding assistant** | A small, well-bounded codebase with explicit contracts (see §4). |

---

## 2. Technical Stack & Architecture

### Languages & runtimes
| Component | Technology | Minimum version | Notes |
|---|---|---|---|
| CLI & orchestration | **Bash** | 3.2+ | Compatible with the macOS system Bash; no Bash-4 features used. |
| Parsing / rendering / inspection | **Python** | 3.9+ | Standard library only (uses `dict[str,str]` / `set[str]` generics). |
| Version control hook target | **Git** | any modern | Required for `update`; checked by `doctor`. |

### Dependencies
- **Core has no third-party libraries.** The `dotfiles` CLI uses only Bash +
  Python standard library + POSIX tooling (`awk`, `stat`, `ln`, `readlink`, `date`).
- **Optional, OS-specific:** [Homebrew](https://brew.sh) (macOS package setup via
  `Brewfile`) and `apt`/`apt-get` (Debian/Ubuntu package setup). Both degrade
  gracefully when absent.
- **Optional shell ecosystem:** both shells integrate `bat`, `fzf`, `zoxide`, `direnv`,
  `pyenv`, and nvm (lazy-loaded). The zsh config additionally wires
  [oh-my-zsh](https://ohmyz.sh) + [powerlevel10k](https://github.com/romkatv/powerlevel10k);
  the bash config uses [bashify](https://github.com/beratiyilik/bashify) (a
  standalone p10k-style prompt installed to `~/.bashify`). The
  1Password CLI (`op`) backs SSH agent. Every integration is guarded by a
  `command -v` / file check — the shell starts cleanly when a tool is missing.
  `dotfiles os` (Brewfile) installs optional tools; `hooks/post-init.sh` clones
  oh-my-zsh + plugins + powerlevel10k and installs bashify.
- **No database.** State is the filesystem: the `.symlinks` manifest plus the real
  symlinks/templates it produces in `$HOME`.

### Architecture summary
A **manifest-driven, library-based CLI** — effectively a small modular monolith with
a deliberate two-language split:

- **Bash performs side effects.** The entrypoint [`bin/dotfiles`](bin/dotfiles) is a
  thin command dispatcher that *sources* small single-responsibility libraries from
  [`core/`](core/) (symlinking, backups, detection, health checks).
- **Python performs pure logic.** Read-only or transform-only work — manifest
  parsing, health inspection (`doctor`), template rendering, package diffing —
  lives in [`core/py/`](core/py/) and is invoked as subprocesses.

The two languages share **identical parsing contracts** for the `.symlinks` manifest
and the `KEY=value` env format, so behavior is consistent regardless of which side
reads a file. Configuration content is grouped by domain under
[`shell/`](shell/), [`config/`](config/), and [`os/`](os/), with extension points in
[`hooks/`](hooks/).

```
install.sh ──> dotfiles init
                 ├─ hooks/pre-init.sh        (optional)
                 ├─ core/symlinks.sh ─ link_all()
                 │    ├─ parse .symlinks            (Bash awk)
                 │    ├─ backup_file()              (existing real files)
                 │    ├─ ln -sf                     (normal entries)
                 │    └─ python core/py/template.py ([template] entries → 0600)
                 ├─ os/macos/defaults.sh --all --force  OR  os/linux/apt.sh
                 └─ hooks/post-init.sh       (optional)

dotfiles doctor ──> python? core/py/doctor.py  :  core/doctor.sh run_doctor()
                    (fail > 0 ⇒ exit 1)
dotf ──> bin/dotf shim ──> bin/dotfiles
```

---

## 3. For Humans: Quick Start & Usage

### Prerequisites
- macOS or Linux with **Bash** and **Git**.
- **Python 3.9+** (required for `os --diff`, `[template]` entries, and the full
  `doctor`; without it `doctor` runs a more minimal pure-bash version and plain
  `link`/`init` still work for non-template entries).

### Install

**Option A — bootstrap from a fresh machine (recommended layout `~/dotfiles`):**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/beratiyilik/dotfiles/HEAD/install.sh)"
```

This works on a *bare* machine with **neither `git` nor SSH keys**: when `git` is
available the repo is cloned over HTTPS; otherwise `install.sh` falls back to
downloading a tarball with `curl` + `tar` (see
[Installing without git](#installing-without-git)). In bootstrap mode it installs
the **latest release tag** when one exists and otherwise tracks `DOTFILES_BRANCH`;
**re-running the one-liner updates an existing clone in place** (`git fetch` +
checkout), so it doubles as an updater.

**Option B — clone to a custom directory:**
```bash
git clone https://github.com/beratiyilik/dotfiles.git ~/code/dotfiles
~/code/dotfiles/install.sh        # custom path auto-detected
```

`install.sh` first prints a short **preview of what it will do and waits for you to
press `RETURN`** before changing anything; it then resolves `$DOTFILES`, makes the
CLI executable, puts `bin/` on `PATH` for the current shell, and runs
`dotfiles init`. After it finishes, open a new shell (or `source ~/.zshrc` /
`~/.bashrc`) so `dotfiles`/`dotf` are on your `PATH` permanently.

The confirmation prompt is **skipped automatically** when input is non-interactive
— a pipe (`curl … | bash`), CI (`$CI` set), or any non-TTY `stdin`. To force it off
explicitly (e.g. in a provisioning script), set `NONINTERACTIVE=1`. On failure the
installer aborts with a single `Error: …` line naming the step that failed, and
network operations (clone / fetch / tarball) are retried with backoff.

### Installing without git

When `git` is unavailable (a fresh machine, or macOS before the Command Line Tools
are installed), `install.sh` downloads a source tarball with `curl` + `tar` instead
of cloning. Everything works **except** `dotfiles update`, because the result is a
plain directory with no `.git`. `dotfiles doctor` flags this with
*"$DOTFILES is not a git repo"*.

Once `git` is available you can convert the tarball install into a real clone in
place — no re-download, your `vars/local.env` and symlinks are untouched:
```bash
cd "$DOTFILES"
git init && git remote add origin https://github.com/beratiyilik/dotfiles.git
git fetch origin && git reset --hard origin/main
# repo owner: switch the remote to SSH so you can push afterwards
git remote set-url origin git@github.com:beratiyilik/dotfiles.git
```

### Environment variables
| Variable | Purpose | Default |
|---|---|---|
| `DOTFILES` | Absolute path to the repo. Honored if set; otherwise self-derived from the script/rc location (symlinks resolved). | `$HOME/dotfiles` |
| `DOTFILES_SLUG` | GitHub `owner/repo`, used to derive the HTTPS clone URL and the tarball-fallback URL in bootstrap mode. | `beratiyilik/dotfiles` |
| `DOTFILES_BRANCH` | Branch tracked in bootstrap mode **when no release tag and no `DOTFILES_REF` is found**. | `main` |
| `DOTFILES_REF` | Pin a specific tag / branch / commit to check out in bootstrap mode. Overrides the default "latest tag, else branch" resolution. | *(unset)* |
| `DOTFILES_REPO` | Clone URL used by `install.sh` in bootstrap mode. Set the `git@…:…` form to clone over SSH instead of HTTPS. | `https://github.com/$DOTFILES_SLUG.git` |
| `NONINTERACTIVE` | When set, skip the confirmation prompt (also auto-enabled under `$CI` or a non-TTY `stdin`). | *(unset)* |
| `CI` | Treated as `NONINTERACTIVE` (prints a notice and skips the prompt). | *(unset)* |

### Machine-specific secrets
[`vars/local.env`](vars/local.env) is the **single** non-committed override file
(gitignored). `install.sh` creates it automatically from
[`vars/local.env.sample`](vars/local.env.sample) on first run; on an existing
clone, copy it manually:

```sh
cp vars/local.env.sample vars/local.env
# then open vars/local.env and fill in your values
```

`exports.sh` loads it after `vars/common.env` (so any key here overrides the
common default). `core/py/template.py` also reads it for `{{VAR}}` substitution
in `.tmpl` files. One file, one place — see
[`docs/INTERNALS.md`](docs/INTERNALS.md) for the full decision
table.

(No template ships by default — SSH is a static `config/ssh/config` backed by the
1Password agent — but the template subsystem remains available for files you want
rendered with secrets.)

### Everyday commands
```bash
dotfiles link        # (re)create symlinks & render templates to match .symlinks
dotfiles doctor      # health-check environment, links (OK / WRONG / MISSING), permissions, tooling
dotfiles update      # git pull --ff-only, then re-link
dotfiles os          # run OS package setup (brew bundle / apt install)
dotfiles os --diff   # show installed-vs-Brewfile differences (no changes made)
dotfiles backup      # copy current real configs into $DOTFILES/backups/backup_<timestamp>
```
`dotf` is an exact alias for `dotfiles`.

### Maintenance (optional)
These dispatch to the standalone scripts under `os/<detected-os>/` (each supports
`--dry-run`, `--help`; run with `--help` for full options). The macOS scripts in
[`os/macos/`](os/macos/) are implemented; the [`os/linux/`](os/linux/) equivalents
are currently placeholder stubs that just print a "not implemented yet" notice.
```bash
dotfiles upgrade     # update system packages: brew, mas, npm/pnpm, gem, pip
dotfiles cleanup     # remove .DS_Store / Vim swap / __pycache__ / trash / logs / temp
dotfiles snapshot    # dump a full environment inventory into $DOTFILES/backups/snapshot_<ts>/
dotfiles defaults    # apply opinionated OS preferences from defaults.conf (Dock, Finder, keyboard…)
dotfiles defaults --sync # capture this machine's drift into defaults.local.conf (gitignored)
```
> `cleanup`, `snapshot`, and `defaults` are destructive or system-altering — always
> preview with `--dry-run` first. They share [`os/lib.sh`](os/lib.sh)
> (logging, dry-run executor, sudo keep-alive, confirm prompts).

### Build / test
There is no compile step. To validate changes locally before linking:
```bash
bash -n bin/dotfiles core/*.sh os/lib.sh os/macos/*.sh os/linux/*.sh   # Bash syntax check
zsh  -n shell/zsh/.zshenv shell/zsh/.zshrc shell/zsh/.zprofile  # zsh syntax check (if zsh present)
python3 -m py_compile core/py/*.py                           # Python syntax check
dotfiles doctor                       # functional smoke test
```

### Troubleshooting
| Symptom | Likely cause & fix |
|---|---|
| `dotfiles: command not found` | `bin/` isn't on `PATH` yet. Open a new shell, or `path_prepend "$DOTFILES/bin"`. `doctor` warns about this. |
| Cloned repo is empty / `bin/dotfiles: No such file` | You cloned before committing. `git clone` copies only **committed** files — commit first. |
| `python3 not found` on `os --diff` | Install Python 3.9+. Plain `link`/`init` still work for non-template entries; `doctor` falls back to a minimal bash version. |
| `[template] warning: X is not defined` | A `{{X}}` placeholder has no value. Define `X` in `vars/common.env` or `vars/local.env`. |
| SSH ignores `~/.ssh/config` | Permissions. `doctor` checks for `0600` on the file and `0700` on `~/.ssh`; `link` sets these automatically. |
| `doctor` reports "uncommitted changes" / "behind upstream" | Informational warnings, not failures. Commit or run `dotfiles update`. |
| Existing config replaced | Originals are copied to `$DOTFILES/backups/backup_<timestamp>/` before linking. |

---

## 4. For AI Assistants: Context & Codespace Guidelines

### Directory map
| Path | Responsibility |
|---|---|
| [`bin/dotfiles`](bin/dotfiles) | **Entrypoint & command router.** Self-locates `DOTFILES`, sources `core/` libs, dispatches `cmd_*` functions. `set -euo pipefail`. |
| [`bin/dotf`](bin/dotf) | Relative symlink → `dotfiles` (alias; no separate logic). |
| [`tools/`](tools/) | Standalone personal CLI utilities, unrelated to the manager. On `PATH` like `bin/`. [`tools/ai_rename`](tools/ai_rename) (content-based file renamer via local Ollama); [`tools/archive`](tools/archive) (backup/pack/extract/vault — short aliases `bkf`/`tgz`/`extr`/`vault`); [`tools/git_ai`](tools/git_ai) (AI commit/branch/rebase — aliases `ai_commit`/`ai_branch`/`ai_rebase`). |
| [`core/detect.sh`](core/detect.sh) | OS / shell / python detection (`detect_os`, `detect_shell`, `detect_python`). |
| [`core/utils.sh`](core/utils.sh) | Logging (`log_info/ok/warn/error`), `confirm`, color constants. Idempotent via the `__DF_UTILS_LOADED` guard. |
| [`core/paths.sh`](core/paths.sh) | Single source of truth for backup/snapshot output: `DF_BACKUPS_ROOT`, `DF_BACKUP_TS_FORMAT`, `df_backup_stamp`. Sourced by `core/backup.sh` and `os/macos/snapshot.sh`. |
| [`core/backup.sh`](core/backup.sh) | `backup_file` → copies real (non-symlink) targets into `$DOTFILES/backups/backup_<ts>/`. |
| [`core/symlinks.sh`](core/symlinks.sh) | `link_all` — the manifest executor (parse → backup → `ln -sf` / render). |
| [`core/doctor.sh`](core/doctor.sh) | Minimal pure-bash `doctor` fallback (no python): `run_doctor` + `check_*`, accumulates `DOCTOR_OK/WARN/FAIL`. |
| [`core/py/manifest.py`](core/py/manifest.py) | Canonical Python manifest parser → `list[SymlinkEntry]`. Importable module. |
| [`core/py/doctor.py`](core/py/doctor.py) | Full `doctor` (env/tooling/symlinks/permissions); used when python3 is present. Consumes `manifest.parse` and renders the per-target link state that used to be `dotfiles status`. |
| [`core/py/template.py`](core/py/template.py) | `{{VAR}}` renderer; applies `0600` (file) / `0700` (`~/.ssh`). |
| [`core/py/packages.py`](core/py/packages.py) | Brewfile vs. installed package diff. |
| [`shell/common/`](shell/common/) | Cross-shell (Bash+Zsh) libraries sourced by both `.zshrc` and `.bashrc`: `exports.sh` (env, workspace paths, tool config, PATH helpers, feature flags, `vars/common.env` + `vars/local.env` loader), `functions.sh` and `aliases.sh` (unified), `git.sh` (git status/log wrappers + `ai_commit`/`ai_branch`/`ai_rebase` aliases to `tools/git_ai`), `diag.sh` (`shelldiag` — live shell/system/terminal/PATH report), `nvm.sh` (lazy nvm loader — sets aliases that trigger a one-time source on first use), `tool_loader.sh` (feature-flag dispatch — conditionally sources `nvm.sh`/`git.sh`/`aws.sh`/`esp.sh` based on `DOTFILES_ENABLE_*`), `aws.sh` (`awsm`/`awssp`/`awsset`/`awsst`/`awstest` — AWS profile/credential manager), `esp.sh` (`esp`/`esp32`/`esp8266` — ESP-IDF env switcher). |
| [`shell/zsh/`](shell/zsh/) | zsh startup: `.zshenv` (sources `exports.sh`), `.zshrc` (PATH, homebrew, pyenv, oh-my-zsh + plugins + p10k, completion, fzf, zoxide, then sources `functions.sh`/`aliases.sh`/`diag.sh`/`tool_loader.sh`), `.zprofile`, `.zsh_history_seed`. |
| [`shell/bash/`](shell/bash/) | bash startup: `.bash_profile` (sources `.bashrc`), `.bashrc` (single interactive file — self-locates `DOTFILES`, homebrew, history, `shopt`, sources all `shell/common/` libs, bash-completion, direnv, bat, pyenv, rbenv stub, fzf, zoxide, PATH), then sources [bashify](https://github.com/beratiyilik/bashify) from `~/.bashify` as the prompt (standalone project installed by `hooks/post-init.sh`; user config linked at `~/.config/bashify/bashifyrc`). |
| [`config/`](config/) | App configs by domain: `git/` (incl. `.gitmessage`), `vim/`, `nano/`, `tmux/`, `ssh/` (static config), `readline/`, `editorconfig/`, `aws/`, `1Password/`, `fzf/`, `p10k/`, `starship/`, `homebrew/` (the canonical `Brewfile`). |
| [`os/lib.sh`](os/lib.sh) | Shared bash utilities for the per-OS maintenance scripts (logging, dry-run executor, `confirm_prompt`, sudo keep-alive). Sourced as `../lib.sh` by `os/<os>/*.sh`. |
| [`os/macos/`](os/macos/), [`os/linux/`](os/linux/) | OS scripts (dispatched by detected OS: `dotfiles upgrade/cleanup/snapshot/defaults` → `os/$OS/{update,cleanup,snapshot,defaults}.sh`). macOS: `defaults.sh` (data-driven engine reading `defaults.conf` + optional gitignored `defaults.local.conf` overrides), `update.sh`, `cleanup.sh`, `snapshot.sh`. Linux: `apt.sh` + `packages.txt`, plus placeholder maintenance stubs `update.sh`/`cleanup.sh`/`snapshot.sh`/`defaults.sh` (echo-only, not implemented yet). macOS packages live in `config/homebrew/Brewfile`. |
| [`hooks/`](hooks/) | `pre-init.sh` / `post-init.sh` extension points (sourced if present). |
| [`vars/`](vars/) | `common.env` (committed defaults), `local.env.sample` (committed template), `local.env` (gitignored — created from sample on first `install.sh` run). |
| [`.symlinks`](.symlinks) | **The manifest.** Source of truth for what links where. |
| [`install.sh`](install.sh) | Bootstrap (local or curl-pipe). |

> **Tests:** there is no automated test suite. Treat `dotfiles doctor` plus the
> syntax checks in §3 as the verification gate. When adding logic, prefer an
> isolated smoke test: run commands with `HOME="$(mktemp -d)"` and `DOTFILES`
> pointed at the repo so nothing touches the real home directory.

### Design patterns & conventions
- **Manifest-driven state.** Never hard-code link paths in logic; read them from
  `.symlinks`. Both the Bash executor and `manifest.py` must interpret it the same
  way (the **parity contract**).
- **Bash = effects, Python = pure logic.** Keep filesystem mutation and OS calls in
  Bash; keep parsing/rendering/diffing in Python. Don't blur this line.
- **Sourced-library pattern.** Files in `core/` are sourced, not executed. Each
  opens with `: "${DOTFILES:?...}"` (fail loud — they are only ever reached via
  `bin/dotfiles`, which exports `DOTFILES`), a `__DF_<NAME>_LOADED` double-source
  guard, then sources its deps. OS scripts use `return 0` (not `exit`) for early-out,
  because they are sourced. **See [`docs/INTERNALS.md`](docs/INTERNALS.md)
  for the full set of canonical sourcing / path-resolution / invocation patterns.**
- **Self-location / relocation.** Only the *entry points* derive `DOTFILES` from their
  own resolved path (so the repo works from any location): `bin/dotfiles`, `install.sh`,
  `.zshenv` (canonical for zsh), and `.bashrc` (canonical for bash); `.zshrc` keeps a
  guarded fallback. Sourced libraries never re-derive it. Preserve this split when editing.
- **Idempotency.** `ln -sf`, `path_prepend` (dedupes `PATH`), and `defaults … || true`
  must remain safe to run repeatedly.
- **`set -e` safety.** `bin/dotfiles` runs under `set -euo pipefail`. Any function
  whose last statement can evaluate false (e.g. `[[ … ]] && _warn`) must be called
  guardedly when bare (see `run_doctor`'s `|| true` calls) so it doesn't abort the
  process. New `check_*`-style helpers must follow this.
- **Logging.** User-facing messages go through `log_info/ok/warn/error`; doctor
  results through `_pass/_warn/_fail`. Don't `echo` raw status text.
- **Naming.** `cmd_<command>` for CLI handlers; `snake_case` for Bash functions and
  Python; `UPPER_SNAKE` for env/globals. `_leading_underscore` marks
  Python-module-private and Bash internal helpers.
- **Style.** English comments only; ASCII source. The sole intentional non-ASCII
  characters are the `→` manifest/log separator and the `—` em-dash in prose
  comments — **do not** introduce other non-ASCII or re-ASCII these without intent.
- **Python.** Standard library only; honor `DOTFILES` via
  `os.environ.get("DOTFILES", …)`; keep type hints; `manifest.py` is the single
  parser others import.

### How to add features or refactor
- **Manage a new dotfile:** add the file under the right domain dir, then add one
  line to `.symlinks`: `relative/source → ~/target`. Run `dotfiles link`, then
  `dotfiles doctor`.
- **Add a templated/secret file:** create a `*.tmpl` with `{{VAR}}` placeholders,
  add a `.symlinks` line ending in `[template]`, and define `VAR` in
  `vars/common.env` (defaults) or `vars/local.env` (secrets).
- **Add a CLI command:** implement `cmd_<name>` in `bin/dotfiles`, add a `case`
  branch, and add a line to the `usage()` heredoc. Gate Python-dependent commands
  with the existing `[[ -z "$PYTHON" ]]` check.
- **Add a doctor check:** add it to **both** doctor paths to preserve parity —
  a `check_<thing>()` in `core/py/doctor.py` (the python implementation) and a
  matching bash `check_<thing>` in `core/doctor.sh` using `_pass/_warn/_fail`,
  called from `run_doctor` with `|| true`.
- **Refactoring guardrails:** keep the Bash/Python manifest & env parity, the
  sourced-library guards, relocation self-location, idempotency, and `set -e`
  safety. After any change, run the §3 syntax checks and `dotfiles doctor` in an
  isolated `HOME`.

---

## 5. CLI Reference & Data Contracts

> This project exposes **no HTTP API**. Its public surface is the `dotfiles` CLI and
> the file formats it consumes.

### Command reference
| Command | Arguments | Requires `python3` | Description | Exit behavior |
|---|---|:--:|---|---|
| `init` | — | for templates | Run `pre-init` hook → `link` → OS setup → `post-init` hook. | non-zero on fatal error (`set -e`) |
| `link` | — | for templates | Create/update symlinks and render templates per `.symlinks`. | 0 on success |
| `update` | — | for templates | `git -C $DOTFILES pull --ff-only` then `link`. | non-zero if pull fails |
| `doctor` | — | preferred | Audit env, PATH, git, tooling, per-target link state (`OK`/`WRONG`/`MISSING`/not-linked), permissions. Runs `core/py/doctor.py` when `python3` is present, else the minimal `core/doctor.sh`. | **1 if any `fail`**, else 0 |
| `os` | — | no | macOS: `brew bundle`. Linux: `apt install` from `packages.txt`. | depends on package manager |
| `os` | `--diff` | **yes** | Show installed-vs-`Brewfile` formula/cask differences. Read-only. | 1 if `python3` missing |
| `backup` | `-h`/`--help` | no | Copy current real configs to `$DOTFILES/backups/backup_<timestamp>/`. | 0 on success |
| `upgrade` | passthrough | no | OS-dispatched (`os/$OS/update.sh`). macOS: brew, mas, npm/pnpm, gem, pip. Linux: placeholder stub (echoes "not implemented yet"). | child exit code; non-zero only if no script for the OS |
| `cleanup` | passthrough | no | OS-dispatched (`os/$OS/cleanup.sh`). macOS: caches/.DS_Store/swap/trash/logs/temp. Linux: placeholder stub (echoes "not implemented yet"). | child exit code; non-zero only if no script for the OS |
| `snapshot` | passthrough | no | OS-dispatched (`os/$OS/snapshot.sh`). macOS: environment inventory to `$DOTFILES/backups/snapshot_<ts>/`. Linux: placeholder stub (echoes "not implemented yet"). | child exit code; non-zero only if no script for the OS |
| `defaults` | passthrough | no | OS-dispatched (`os/$OS/defaults.sh`). macOS: apply prefs from `defaults.conf` via `defaults write`; `--sync` captures drift into `defaults.local.conf`. Linux: placeholder stub (echoes "not implemented yet"). | child exit code; non-zero only if no script for the OS |
| `help` | `--help`, `-h` | no | Print usage. | 0 |
| *(unknown)* | — | — | Print error + usage. | 1 |

### `.symlinks` manifest format
Whitespace-separated, one entry per line. `#` starts a comment; blank lines ignored.
The token separator is a literal `→` (U+2192).

```
<source-relative-to-repo>  →  <target-absolute-or-~>  [<flag>]
```

| Field | Required | Meaning |
|---|:--:|---|
| source | yes | Path relative to `$DOTFILES`. |
| `→` | yes | Literal separator (field 2). Both Bash and `manifest.py` require it. |
| target | yes | Destination. A leading `~` (and `~/`) expands to `$HOME`; no other expansion. |
| flag | no | `[template]` ⇒ render via `template.py` (mode `0600`) instead of symlinking. |

**Example**
```
shell/zsh/.zshrc             → ~/.zshrc
config/git/.gitmessage       → ~/.gitmessage
config/1Password/agent.toml  → ~/.config/1Password/ssh/agent.toml
# foo.tmpl                   → ~/.foo            [template]   (optional, rendered)
```

### `vars/*.env` format
```
# KEY=value  — NO 'export' keyword, NO shell expansion (plain strings).
SSH_IDENTITY=~/.ssh/id_ed25519
```
Load order is `common.env` then `local.env` (latter overrides). Consumed identically
by the shell (`exports.sh`, auto-exported via `set -a`) and by `template.py`.

### Template syntax
- Placeholder: `{{VAR}}` (whitespace inside braces is trimmed).
- Undefined `VAR` ⇒ left verbatim + a `[template] warning:` on stderr.
- Output permissions: file `0600`; if the parent is `~/.ssh`, the directory is set to `0700`.

### `SymlinkEntry` schema (`core/py/manifest.py`)
```json
{
  "src":         "Path  (absolute, $DOTFILES-rooted)",
  "target":      "Path  (absolute, ~ expanded to $HOME)",
  "is_template": "bool  (true when the [template] flag is present)"
}
```

### Internal contract (Bash → Python)
Python helpers are invoked as subprocesses and rely on two environment values set by
`bin/dotfiles`:
- `DOTFILES` — exported repo root (subprocesses read it via `os.environ`).
- `PYTHONPATH="$DOTFILES/core/py"` — so `doctor.py` can `from manifest import parse`.
