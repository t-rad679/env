# Desktop-only ~/.xprofile fragment. Sourced (not executed) by config/.xprofile
# after it exports MACHINE_ROLE, so everything here runs in LightDM's login
# session before i3 starts and is inherited by i3 and every program it
# launches.
#
# POSIX sh, not zsh, on purpose: LightDM runs ~/.xprofile with sh, and this
# file is sourced into that same shell. It is the same deliberate exception to
# the zsh-only rule as config/.xprofile itself. No shebang because it is a
# fragment meant to be sourced, never run.

# Headless Obsidian: an invisible Obsidian on its own Xvfb display, so
# Claude's Obsidian MCP server (Local REST API plugin) and Obsidian Sync stay
# alive with no window on the real display (see the comment near
# `exec --no-startup-id steam` in machines/desktop/i3/autostart.conf). It runs
# as a transient systemd user unit, so it outlives this login shell and a
# re-login doesn't start a second copy. The script it runs,
# ~/.local/bin/obsidian-headless.zsh, is not in this repo.
if ! systemctl --user is-active --quiet obsidian-headless.service 2>/dev/null; then
  systemd-run --user --unit=obsidian-headless --collect \
    --description="Headless Obsidian for MCP" \
    "$HOME/.local/bin/obsidian-headless.zsh" >/dev/null 2>&1
fi
