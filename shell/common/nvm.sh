# shellcheck shell=bash
# Sourced by shell/common/tool_loader.sh when DOTFILES_ENABLE_NVM=true.
# Lazy-loads nvm: sets up aliases for node/npm/nvm/yarn/npx/pnpm that trigger
# a one-time real source of nvm.sh on first use, keeping shell startup fast.
[[ -n "${__DF_NVM_LOADED:-}" ]] && return 0
readonly __DF_NVM_LOADED=1

setup_nvm_lazy() {
	export NVM_DIR="${NVM_DIR:-$([ -n "$BREW_DIR" ] && [ -d "$BREW_DIR/opt/nvm" ] && echo "$BREW_DIR/opt/nvm" || echo "$HOME/.nvm")}"

	if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
		printf '[warn] nvm.sh not found at %s\n' "$NVM_DIR" >&2
		return 1
	fi

	_dispatch_nvm_command() {
		local cmd_name="$1"
		shift
    
		unset -f _dispatch_nvm_command
		unalias node npm nvm yarn npx pnpm 2>/dev/null || true

		# shellcheck disable=SC1090,SC1091
		source "$NVM_DIR/nvm.sh"
		# shellcheck disable=SC1090,SC1091
		[[ -s "$NVM_DIR/etc/bash_completion.d/nvm" ]] && source "$NVM_DIR/etc/bash_completion.d/nvm"
		# shellcheck disable=SC1090,SC1091
		[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

		if ! command -v "$cmd_name" &>/dev/null; then
			printf '[ERROR] Command "%s" not available after sourcing nvm\n' "$cmd_name" >&2
			return 127
		fi

		"$cmd_name" "$@"
	}

	for cmd in node npm nvm yarn npx pnpm; do
		# shellcheck disable=SC2139
		alias "$cmd"="_dispatch_nvm_command $cmd"
	done
}

setup_nvm_lazy
