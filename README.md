# Dotfiles

Personal dotfiles and configuration files for macOS — managed via a unified CLI.

## Quick Start

```bash
# 1. Clone
git clone https://github.com/beratiyilik/dotfiles.git ~/dotfiles

# 2. Install
sh ~/dotfiles/init.sh
```

The installer creates all symlinks, optionally installs Homebrew packages and oh-my-zsh, and is safe to re-run at any time. Existing files are backed up to `<file>.bak` before being replaced.

## CLI

```text
dotfiles <command> [options]
```

| Command | Description |
| --- | --- |
| `init` | Bootstrap the dotfiles installation |
| `doctor` | Check installation health |
| `defaults` | Apply macOS system preferences |
| `backup` | Create a timestamped environment backup |
| `help` | Show help |

The repo root is added to `PATH` by `.zshrc`, so after the first `init` you can run `dotfiles <command>` from anywhere. A short alias `df` is also provided at the repo root.

### `dotfiles init`

```bash
dotfiles init [--dry-run] [--force] [--no-brew] [--no-omz] [--no-shell]
```

Steps performed:

1. Creates required directories (`~/.config`, `~/.config/1Password/ssh`, `~/.aws`, `~/.ssh` with 700)
2. Creates all symlinks defined in `dotfiles.conf`
3. Installs Homebrew and runs `brew bundle` *(optional, prompted)*
4. Installs oh-my-zsh and plugins *(optional, prompted)*
5. Sets zsh as the default shell *(optional, prompted)*
6. Seeds `~/.zsh_history` from the history seed file *(optional, prompted)*

| Flag | Description |
| --- | --- |
| `--dry-run` | Preview all changes without applying them |
| `--force` | Auto-answer yes to all prompts |
| `--no-brew` | Skip Homebrew installation and Brewfile |
| `--no-omz` | Skip oh-my-zsh and plugins |
| `--no-shell` | Skip setting zsh as default shell |

### `dotfiles doctor`

Checks symlinks, required directories, essential commands, and optional tool availability. Exits 0 if everything is healthy.

```bash
dotfiles doctor          # report only
dotfiles doctor --fix    # report and re-run init to repair failures
```

### `dotfiles defaults` *(macOS)*

Applies opinionated macOS system preferences via `defaults write`.

```bash
dotfiles defaults                       # apply all sections
dotfiles defaults --dock --finder       # apply specific sections
dotfiles defaults --dry-run             # preview without applying
dotfiles defaults --force               # skip confirmation prompt
```

Sections: `--dock`, `--finder`, `--keyboard`, `--screenshots`, `--global`

### `dotfiles backup` *(macOS)*

Creates a timestamped backup directory under `$DOTFILES_DIR/backups/`.

```bash
dotfiles backup                         # all sections
dotfiles backup --brew --node --python  # specific sections
dotfiles backup --output ~/my-backups   # custom output directory
dotfiles backup --dry-run               # preview without writing
```

Sections: `--system`, `--network`, `--env`, `--apps`, `--brew`, `--node`, `--python`, `--ruby`, `--dotnet`, `--vscode`, `--browsers`, `--crontab`, `--defaults`

Output structure:

```text
dotfiles/backups/
└── YYYYMMDD_HHmm/
    ├── system.txt
    ├── brew.txt
    ├── ...
    └── backup.txt    # combined summary
```

## Repository Structure

```text
dotfiles/
├── dotfiles             # CLI entry point
├── df                   # short alias for the CLI
├── init.sh              # legacy entry point (forwards to dotfiles init)
├── dotfiles.conf        # symlink manifest and installer configuration
│
├── lib/
│   ├── env.sh               # environment variables and feature flags
│   ├── aliases.sh           # shell aliases (Bash + Zsh)
│   ├── functions.sh         # shell utility functions
│   ├── colors.sh            # ANSI color constants (256-color with fallback)
│   ├── log.sh               # structured logging library
│   ├── tool_loader.sh       # lazy-loads helpers via DOTFILES_ENABLE_* flags
│   ├── archive_helpers.sh   # tgz, extract, encrypt/decrypt, backup helpers
│   ├── git_helpers.sh       # git status, AI-assisted commit and rebase
│   ├── aws_helpers.sh       # AWS session and credential helpers
│   ├── esp_idf_helpers.sh   # ESP-IDF environment helpers
│   └── ai_rename.sh         # AI-powered file renaming via local Ollama model
│
├── config/
│   ├── 1Password/       # 1Password SSH agent (agent.toml)
│   ├── aws/             # AWS CLI config
│   ├── editorconfig/    # .editorconfig
│   ├── fzf/             # fzf shell integration
│   ├── git/             # .gitconfig, .gitignore_global, .gitmessage
│   ├── homebrew/        # Brewfile
│   ├── nano/            # .nanorc
│   ├── p10k/            # Powerlevel10k prompt theme
│   ├── readline/        # .inputrc
│   ├── ssh/             # SSH config (linked with 600)
│   ├── starship/        # Starship prompt config
│   ├── tmux/            # .tmux.conf
│   └── vim/             # .vimrc
│
├── scripts/
│   ├── doctor.sh            # health check (called by dotfiles doctor)
│   ├── shell_diagnostics.sh # shell environment diagnostics
│   ├── bash/
│   │   └── bashify.bash     # bash compatibility shim
│   └── macos/
│       ├── _lib.zsh         # shared utilities for macOS scripts
│       ├── defaults.zsh     # macOS system preferences
│       ├── backup.zsh       # environment backup script
│       ├── update.zsh       # system-wide package updater
│       └── cleanup.zsh      # system cleanup (DS_Store, swap, trash, logs, tmp)
│
├── shell/
│   ├── bash/
│   │   ├── .bashrc
│   │   └── .bash_profile
│   └── zsh/
│       ├── .zshenv          # sources lib/env.sh (always loaded, all shells)
│       ├── .zprofile        # login shell setup
│       ├── .zshrc           # interactive shell config
│       └── .zsh_history_seed
│
└── docs/
    ├── MANIFEST.md
    ├── NAMING_CONVENTIONS.md
    ├── FILE_NAMING_CONVENTION.md
    ├── GIT_COMMIT_MESSAGE_CONVENTION.md
    └── STANDARDS_AND_PRACTICES.md
```

## Configuration

All symlinks, required directories, and oh-my-zsh plugins are defined in `dotfiles.conf`. The CLI and `doctor` both source this file — no other script needs to be modified.

### Symlink format

```bash
# dotfiles.conf
# "src:dst[:mode]"
#   src  — path relative to DOTFILES_DIR
#   dst  — path relative to $HOME
#   mode — optional chmod (e.g. 600 for SSH config)

SYMLINKS=(
  "config/git/.gitconfig:.gitconfig"
  "config/ssh/config:.ssh/config:600"
)
```

Re-run `dotfiles init` after any change to apply it.

### oh-my-zsh plugin format

```bash
# "label|repo_url|install_subpath"
OMZ_PLUGINS=(
  "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions|plugins/zsh-autosuggestions"
)
```

Installed plugins: `powerlevel10k`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `zsh-history-substring-search`

## Shell Layer

`.zshenv` → `lib/env.sh` (always loaded, all shells)  
`.zshrc` → oh-my-zsh + plugins + `lib/functions.sh` + `lib/aliases.sh` + `lib/tool_loader.sh`

Also configured in `.zshrc`: `direnv`, `zoxide`, `pyenv`, `fzf`, Docker CLI completions.

### Feature flags

Helper scripts are lazy-loaded via feature flags in `lib/env.sh`:

| Flag | Default | Script |
| --- | --- | --- |
| `DOTFILES_ENABLE_NVM` | `true` | nvm lazy initialization |
| `DOTFILES_ENABLE_ARCHIVE_HELPERS` | `true` | `lib/archive_helpers.sh` |
| `DOTFILES_ENABLE_GIT_HELPERS` | `true` | `lib/git_helpers.sh` |
| `DOTFILES_ENABLE_AWS_HELPERS` | `false` | `lib/aws_helpers.sh` |
| `DOTFILES_ENABLE_ESP_IDF_HELPERS` | `false` | `lib/esp_idf_helpers.sh` |
| `DOTFILES_ENABLE_AI_RENAME` | `true` | `lib/ai_rename.sh` |

Override any flag without touching `lib/env.sh` by creating `~/.dotfiles.local`:

```bash
# ~/.dotfiles.local  — never committed
export DOTFILES_ENABLE_AWS_HELPERS=true
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_..."
export CLAUDE_API_KEY="sk-ant-..."
```

You can also load any helper on-demand at any time:

```bash
source_git_helpers      # loads lib/git_helpers.sh
source_aws_helpers      # loads lib/aws_helpers.sh
source_archive_helpers  # loads lib/archive_helpers.sh
source_esp_idf_helpers  # loads lib/esp_idf_helpers.sh
source_ai_rename        # loads lib/ai_rename.sh
```

## AI Features

`lib/git_helpers.sh` and `lib/ai_rename.sh` provide AI-assisted workflows powered by a local [Ollama](https://ollama.ai) model (default: `qwen2.5-coder:7b`).

| Alias | Description |
| --- | --- |
| `ai_commit` | Generate a commit message for staged changes and open the editor to review |
| `ai_rebase` | Interactive rebase with AI-assisted squash message generation |
| `ai_rename` / `air` | Rename a file based on its content |
| `gss` | Short git status (branch, file counts, changed files) |
| `gsd` | Detailed git status (adds remote tracking, stash, last commit) |
| `glf` | Decorated graph log (hash, branch, message, date, author) |

Requirements:

- `ollama` running locally (`ollama serve`)
- `curl` and `jq`
- Model pulled: `ollama pull qwen2.5-coder:7b`

Override the model or endpoint in `~/.dotfiles.local`:

```bash
export AI_DEFAULT_SMALL_MODEL="llama3.2:3b"
export AI_API_URL="http://localhost:11434/api/generate"
```

The convention used for commit messages is loaded from `docs/GIT_COMMIT_MESSAGE_CONVENTION.md`; file names from `docs/FILE_NAMING_CONVENTION.md`.

## macOS Maintenance Aliases

After `dotfiles init`, these aliases are available in your shell:

| Alias | Action |
| --- | --- |
| `update` | macOS + App Store + Homebrew + Node + Ruby + Python updates |
| `cleanup` | Selectively clean: `--ds`, `--swap`, `--py`, `--trash`, `--logs`, `--tmp`, or `-a` for all |
| `maintain` | `update` then `cleanup -a` |
| `maintain-full` | `update --yes` then `cleanup -a --yes` (fully non-interactive) |
| `backup` | Create environment backup |
| `backup-full` | Full backup (all sections) |
| `brewfile-update` | Regenerate `Brewfile` from currently installed packages |

## CI

ShellCheck runs on all `.sh` and `.bash` files on every push and pull request (branches: `main`, `dev`):

```text
.github/workflows/shellcheck.yml
```

## License

Licensed under the **GNU General Public License v3.0 (GPL-3.0)**.  
See the [LICENSE](LICENSE) file for details.
