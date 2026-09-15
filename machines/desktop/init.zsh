#!/usr/bin/zsh

# Desktop-only init, sourced last by init/init.zsh when MACHINE_ROLE=desktop
# (also in --links-only mode, so keep everything here idempotent).
#
# Headless Obsidian + Claude remote-control: the helper scripts are in
# machines/desktop/bin (config/zsh/env/path.zsh puts it on PATH), and the
# login-time Xvfb/Obsidian startup has its home in machines/desktop/xprofile.sh
# (sourced by config/.xprofile) -- but that fragment is still a placeholder
# until the desktop's hand-written ~/.xprofile (or ~/.xprofile.bak once init
# has run) is pasted into it. The systemd user unit is not in the repo yet.

source "${ENV_DIR:-$HOME/src/env}/init/lib.zsh"

# LightDM drop-in: force the greeter (login screen) to 1080p on HDMI-3 -- see
# machines/desktop/lightdm.conf.d/50-resolution.conf. LightDM reads every
# *.conf in /etc/lightdm/lightdm.conf.d/, so our drop-in sits alongside whatever
# the package ships. Like pacman.conf, the symlink points back into this repo so
# edits here take effect without re-copying.
sudo_link_path "$ENV_DIR/machines/desktop/lightdm.conf.d/50-resolution.conf" \
    /etc/lightdm/lightdm.conf.d/50-resolution.conf
