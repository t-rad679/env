#!/usr/bin/zsh

# Publish this machine's role (desktop|laptop) as ~/.config/machine-role.env,
# a plain KEY=VALUE file that zsh (config/zsh/.zshrc), the X session
# (config/.xprofile) and i3 (via the exported variable) all read.

source "${ENV_DIR:-$HOME/src/env}/init/lib.zsh"

link_path "$ENV_DIR/machines/$MACHINE_ROLE/machine-role.env" "$HOME/.config/machine-role.env"
