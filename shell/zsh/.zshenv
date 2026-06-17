# zsh sources this on EVERY invocation: interactive, non-interactive, login, script.
# This is the right place for DOTFILES + environment variables (so non-interactive
# zsh, e.g. `ssh host cmd` and GUI-launched processes, also see DOTFILES).
# If the repo lives outside $HOME/dotfiles it self-locates (:A resolves, :h:h:h is root).
if [[ -z "${DOTFILES:-}" ]]; then
    DOTFILES="${${(%):-%x}:A:h:h:h}"
fi
export DOTFILES

source "$DOTFILES/shell/common/exports.sh"
# PATH is NOT set here: on macOS /etc/zprofile → path_helper runs after .zshenv
# and reorders PATH. PATH is set in .zprofile (login) + .zshrc (interactive).
