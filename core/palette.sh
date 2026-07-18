#!/usr/bin/env bash
# Source-only library (see docs/INTERNALS.md). The canonical ANSI palette —
# the FG_*/STYLE_* color and style constants every part of the repo renders
# with. core/utils.sh's log(), os/lib.sh, core/doctor.sh, and the shell/common/*
# libraries all consume these.
#
# Pure leaf: sources nothing and reads no $DOTFILES, so — like core/detect.sh —
# it carries no assertion and is safe to source from any world (bin/dotfiles,
# os/*.sh, and interactive .zshrc/.bashrc alike). This is the *only* thing an
# interactive shell needs for color; it deliberately does not pull in the log()
# engine (see core/utils.sh).
#
# Assign-if-unset, NOT readonly: a caller may pre-set any name before sourcing
# (e.g. FG_RED='' to disable color) and that value wins, and self-defaulting
# consumers (shell/common/esp.sh, aws.sh, diag.sh) may re-assign these names
# without a read-only error. Literal \033 form: safe under a printf format
# string, printf '%b', and echo -e alike — never fed to a bare '%s'.
# Idempotent: guarded against double-sourcing via __DF_PALETTE_LOADED.
[[ -n "${__DF_PALETTE_LOADED:-}" ]] && return 0
readonly __DF_PALETTE_LOADED=1

# attributes
: "${STYLE_RESET:=\033[0m}"
: "${STYLE_BOLD:=\033[1m}"
: "${STYLE_BLINK_ON:=\033[5m}"
: "${STYLE_BLINK_OFF:=\033[25m}"

# foreground colors
: "${FG_BLUE:=\033[38;5;31m}"
: "${FG_CYAN:=\033[38;5;66m}"
: "${FG_GRAY:=\033[38;5;244m}"
: "${FG_GREEN:=\033[38;5;76m}"
: "${FG_MAGENTA:=\033[0;35m}"
: "${FG_RED:=\033[38;5;196m}"
: "${FG_WHITE:=\033[0;37m}"
: "${FG_YELLOW:=\033[38;5;220m}"
