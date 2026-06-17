# fzf — unified setup for bash and zsh

if [[ ! "$PATH" == */opt/homebrew/opt/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/opt/homebrew/opt/fzf/bin"
fi

if [[ -n "$ZSH_VERSION" ]]; then
  source <(fzf --zsh)
elif [[ -n "$BASH_VERSION" ]]; then
  source <(fzf --bash)
  bind -x '"\C-r": _fzf_history'
fi

export FZF_DEFAULT_OPTS="
  --style=full
  --info=inline
  --bind=ctrl-a:select-all,ctrl-d:deselect-all
  --cycle
"

export FZF_CTRL_T_OPTS="
  --preview 'bat --color=always --style=numbers --line-range=:500 {}'
  --preview-window=right:50%:hidden:wrap
  --bind=ctrl-/:toggle-preview
"

export FZF_ALT_C_OPTS="--preview 'tree -C {}'"