#!/usr/bin/env bash

# Entry point for provisioning a fresh Arch install (either machine role).
#
#   init/init.sh                  # desktop (default; --desktopMode also ok)
#   init/init.sh --laptop         # laptop
#   init/init.sh --links-only     # only the symlink/config steps: no packages,
#                                 # no network, no chsh (safe re-run on a
#                                 # machine that is already set up)
#
# Runs under bash on purpose: a brand-new box may not have zsh yet. All it does
# is install zsh and hand off to init/init.zsh, which does the real work.
#
# TODO (left over from the arch/ -> config/ + machines/ restructure, 2026-09-14):
#   1. Paste the desktop's real ~/.xprofile content (headless Obsidian under its
#      own Xvfb display, for the Obsidian MCP server) into
#      machines/desktop/xprofile.sh. It is a marked placeholder until then, so
#      after init re-links ~/.xprofile that startup stops happening at login.
#      If init has already run, the old file is at ~/.xprofile.bak.
#   2. On the desktop, /etc/pacman.conf (and every other link the old init made)
#      still points at the removed arch/ paths. pacman is broken until
#      /etc/pacman.conf is re-pointed at config/pacman.conf by hand (this script
#      runs `pacman -S zsh` before init/pacman.zsh could fix it, and --links-only
#      skips that step), then re-run init here.
#   3. Two things noticed but not fixed: (a) on the Mac, Claude Code replaced
#      the ~/.claude/settings.json symlink with a real file, so the repo copy no
#      longer receives its writes there; (b) ~/bin/gwt uses ${0:A:h} inside a
#      function, where $0 is the function name, so its link_worktrees step only
#      works when run from ~/bin.

set -euo pipefail

role=desktop
links_only=0
for arg in "$@"; do
    case "$arg" in
        --desktop|--desktopMode) role=desktop ;;
        --laptop)                role=laptop ;;
        --links-only)            links_only=1 ;;
        -h|--help)
            sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            echo "init.sh: unknown argument: $arg" >&2
            exit 2 ;;
    esac
done

if [[ $links_only -eq 0 ]]; then
    # Ensure zsh is installed before we hand off to the zsh init flow.
    sudo pacman -S --needed --noconfirm zsh
fi

# Run the real init script (zsh) relative to this file, regardless of cwd.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACHINE_ROLE="$role" INIT_LINKS_ONLY="$links_only" exec zsh "$DIR/init.zsh"
