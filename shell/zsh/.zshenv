# ~/.zshenv
# ${(%):-%x} gives the real path of this file; :A resolves symlinks; :h:h:h walks up to repo root
# (shell/zsh/.zshenv → shell/zsh → shell → dotfiles root)
_df_root="$(cd "${${(%):-%x}:A:h:h:h}" 2>/dev/null && pwd)"
[ -f "$_df_root/lib/env.sh" ] && . "$_df_root/lib/env.sh"
unset _df_root