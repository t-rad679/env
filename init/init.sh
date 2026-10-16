#!/usr/bin/env bash

# Entry point for provisioning a fresh Arch install (either machine role).
#
#   init/init.sh                  # desktop (default; --desktopMode also ok)
#   init/init.sh --spellbook      # spellbook
#   init/init.sh --links-only     # only the symlink/config steps: no packages,
#                                 # no network, no chsh (safe re-run on a
#                                 # machine that is already set up)
#   init/init.sh --force-role     # provision under a role that disagrees with
#                                 # the one ~/.config/machine-role.env already
#                                 # records; refused without it (role guard)
#
# Runs under bash on purpose: a brand-new box may not have zsh yet. All it does
# is install zsh and hand off to init/init.zsh, which does the real work.

# A blank line, not a `#` one: it is what ends the block --help prints, so the
# TODOs below stay out of the usage message without a hardcoded line range.
#
# TODO (left over from the arch/ -> config/ + machines/ restructure, 2026-09-14):
#   1. On the desktop, /etc/pacman.conf (and every other link the old init made)
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
role_given=0
links_only=0
force_role=0
for arg in "$@"; do
    case "$arg" in
        --desktop|--desktopMode) role=desktop; role_given=1 ;;
        --spellbook)             role=spellbook; role_given=1 ;;
        --links-only)            links_only=1 ;;
        --force-role)            force_role=1 ;;
        -h|--help)
            # Everything from the summary down to the first blank line, so
            # adding a usage line above never silently truncates the help the
            # way a hardcoded line range did.
            sed -n '3,/^$/{ /^$/d; s/^# \{0,1\}//; p; }' "${BASH_SOURCE[0]}"
            exit 0 ;;
        *)
            echo "init.sh: unknown argument: $arg" >&2
            exit 2 ;;
    esac
done

# --- role guard ----------------------------------------------------------
#
# No role flag means desktop. That default is deliberate and load-bearing
# everywhere else -- a session that never sourced the role file still gets a
# working config rather than none -- but as an *argument default* on a machine
# that is already provisioned as a spellbook it is never what anyone meant, and
# it fails silently in both directions:
#
#   role.zsh  repoints ~/.config/machine-role.env at the other role, so every
#             new shell, and the i3 include, switch roles.
#   links.zsh repoints ~/.config/niri/role.kdl at the other role's file. The
#             desktop's is comment-only, so niri reloads a config that parses
#             perfectly and has none of the spellbook's binds, named workspaces or
#             window rules -- and `niri validate` still says "config is valid".
#
# The role-only dirs that links.zsh guards on `[[ -d ... ]]` (autorandr,
# wireplumber, ulauncher) survive by accident, which makes the breakage look
# partial and even harder to place.
#
# So: refuse when the requested role contradicts what the machine already
# records, and say which flag was missing. --force-role is the escape hatch for
# genuinely re-provisioning a box under the other role.
role_file="${XDG_CONFIG_HOME:-$HOME/.config}/machine-role.env"
if [[ $force_role -eq 0 && -r $role_file ]]; then
    # The published value, not the symlink target: machine-role.env is the one
    # file the role is declared in, and a hand-written copy is still valid.
    provisioned="$(sed -n 's/^[[:space:]]*MACHINE_ROLE[[:space:]]*=[[:space:]]*\([a-z]\{1,\}\).*/\1/p' \
        "$role_file" | tail -1)"
    if [[ -n $provisioned && $provisioned != "$role" ]]; then
        {
            echo "init.sh: this machine is provisioned as '$provisioned', but you asked for '$role'."
            if [[ $role_given -eq 0 ]]; then
                suggest="${BASH_SOURCE[0]} --$provisioned"
                [[ $links_only -eq 1 ]] && suggest+=" --links-only"
                echo
                echo "  You passed no role flag, and that means --desktop. You almost certainly"
                echo "  want:"
                echo "      $suggest"
            fi
            echo
            echo "  Running as '$role' would repoint ~/.config/machine-role.env and"
            echo "  ~/.config/niri/role.kdl at the '$role' files, which takes out the"
            echo "  '$provisioned' keybindings and workspaces without any error."
            echo
            echo "  If you really are re-provisioning this box as '$role', re-run with"
            echo "  --force-role."
        } >&2
        exit 2
    fi
fi

if [[ $links_only -eq 0 ]]; then
    # Ensure zsh is installed before we hand off to the zsh init flow.
    sudo pacman -S --needed --noconfirm zsh
fi

# Run the real init script (zsh) relative to this file, regardless of cwd.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACHINE_ROLE="$role" INIT_LINKS_ONLY="$links_only" exec zsh "$DIR/init.zsh"
