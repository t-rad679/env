#!/usr/bin/zsh

# Desktop-only init, sourced last by init/init.zsh when MACHINE_ROLE=desktop
# (also in --links-only mode, so keep everything here idempotent).
#
# Headless Obsidian + Claude remote-control (Xvfb, the systemd user unit, the
# .xprofile pieces) are not in the repo yet; their helper scripts are in
# machines/desktop/bin, which config/zsh/env/path.zsh puts on PATH.

source "${ENV_DIR:-$HOME/src/env}/init/lib.zsh"

# LightDM drop-in: force the greeter (login screen) to 1080p on HDMI-3 -- see
# machines/desktop/lightdm.conf.d/50-resolution.conf. LightDM reads every
# *.conf in /etc/lightdm/lightdm.conf.d/, so our drop-in sits alongside whatever
# the package ships. Like pacman.conf, the symlink points back into this repo so
# edits here take effect without re-copying.
sudo_link_path "$ENV_DIR/machines/desktop/lightdm.conf.d/50-resolution.conf" \
    /etc/lightdm/lightdm.conf.d/50-resolution.conf
