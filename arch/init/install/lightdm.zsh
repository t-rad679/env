#!/usr/bin/zsh

# Install my LightDM drop-in config. Currently just forces the greeter (login
# screen) to 1080p on HDMI-3 -- see arch/config/lightdm.conf.d/50-resolution.conf.
#
# LightDM reads every *.conf in /etc/lightdm/lightdm.conf.d/, so we symlink our
# drop-in in alongside whatever the package ships. Like pacman.conf, the symlink
# points back into this repo so edits here take effect without re-copying.

ENV_DIR="${ENV_DIR:-$HOME/src/env}"

sudo mkdir -p /etc/lightdm/lightdm.conf.d
sudo ln -sf "$ENV_DIR/arch/config/lightdm.conf.d/50-resolution.conf" \
    /etc/lightdm/lightdm.conf.d/50-resolution.conf
