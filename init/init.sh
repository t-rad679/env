#!/usr/bin/env bash

# Entry point for provisioning a fresh Arch install (either machine role).
#
#   init/init.sh                  # laptop (default)
#   init/init.sh --desktop        # desktop (--desktopMode also accepted)
#   init/init.sh --links-only     # only the symlink/config steps: no packages,
#                                 # no network, no chsh (safe re-run on a
#                                 # machine that is already set up)
#
# Runs under bash on purpose: a brand-new box may not have zsh yet. All it does
# is install zsh and hand off to init/init.zsh, which does the real work.

set -euo pipefail

role=laptop
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
