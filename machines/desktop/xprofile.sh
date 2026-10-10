# Desktop-only ~/.xprofile fragment. Sourced (not executed) by config/.xprofile
# after it exports MACHINE_ROLE, so everything here runs in LightDM's login
# session before i3 starts and is inherited by i3 and every program it
# launches.
#
# POSIX sh, not zsh, on purpose: LightDM runs ~/.xprofile with sh, and this
# file is sourced into that same shell. It is the same deliberate exception to
# the zsh-only rule as config/.xprofile itself. No shebang because it is a
# fragment meant to be sourced, never run.

# ============================================================================
# TODO: PASTE THE HEADLESS OBSIDIAN / Xvfb STARTUP HERE
if ! systemctl --user is-active --quiet obsidian-headless.service 2>/dev/null; then
  systemd-run --user --unit=obsidian-headless --collect \
    --description="Headless Obsidian for MCP" \
    "$HOME/.local/bin/obsidian-headless.zsh" >/dev/null 2>&1
fi
#
# The desktop's ~/.xprofile was hand-maintained before this fragment existed.
# It starts Obsidian headless under its own Xvfb display (own Electron
# profile) so Claude's Obsidian MCP server can reach it without a window on
# the real display (see the comment near `exec --no-startup-id steam` in
# machines/desktop/i3/autostart.conf, and machines/desktop/init.zsh).
#
# That content is NOT in the repo yet. Copy it from:
#   * ~/.xprofile        on the desktop, if init has not been run yet, or
#   * ~/.xprofile.bak    after init/links.zsh has replaced ~/.xprofile with a
#                        link to config/.xprofile (it backs the real file up
#                        there once and prints a warning when it does).
# Everything in that file except the MACHINE_ROLE export (which
# config/.xprofile already does) belongs below this block.
#
# UNTIL THAT IS DONE, HEADLESS OBSIDIAN DOES NOT START AT LOGIN on a desktop
# provisioned from this repo, and the Obsidian MCP server has nothing to talk
# to.
# ============================================================================
